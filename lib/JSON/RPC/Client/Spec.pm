# ABSTRACT: JSON-RPC client with methods specifications
package JSON::RPC::Client::Spec;
use Moose ();
use Moose::Exporter;
use Moose::Util::MetaRole;
use version; our $VERSION = qv('v0.1');

Moose::Exporter->setup_import_methods(
    as_is => [qw( spec url )],
    also  => 'Moose',
);

sub init_meta {
    shift;
    my %args = @_;
    Moose->init_meta(%args);
    Moose::Util::MetaRole::apply_base_class_roles(
        for   => $args{for_class},
        roles => ['JSON::RPC::Client::SpecRole'],
    );
    return $args{for_class}->meta();
}

sub spec {
    my $class = (caller)[0];
    $class->params_spec(@_);
    $class->make_rpc_method($_[0]);
    return;
}

sub url { (caller)[0]->_url(@_) }

1;

package JSON::RPC::Client::SpecRole;
use 5.010;
use Moose::Role;
use MooseX::ClassAttribute;
use namespace::autoclean;

use Carp;
use Ouch;
use Params::Validate 'validate';
use Scalar::Util 'reftype';
use String::CamelCase 'decamelize';

require LWP::UserAgent;
require JSON::RPC::Legacy::Client;

has username => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_username',
);

has password => (
    is  => 'ro',
    isa => 'Str',
);

has rpc_url => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => 'build_rpc_url',
);

has state_params => (
    is        => 'rw',
    isa       => 'HashRef',
    predicate => 'has_state_params',
    default   => sub { {} },
);

sub build_rpc_url {
    my $self = shift;
    my $url = $self->_url() || croak 'no url defined';
    substr( $url, index( $url, ':' ), 3 )
      = '://' . $self->username() . ':' . $self->password() . '@'
      if $self->has_username();
    return $url;
}

has rpc_client => (
    is      => 'ro',
    isa     => 'JSON::RPC::Legacy::Client',
    lazy    => 1,
    builder => 'build_rpc_client',
);

sub build_rpc_client {
    my $self   = shift;
    my $client = JSON::RPC::Legacy::Client->new();
    my $ua     = LWP::UserAgent->new(
        keepalive => 1,
        ssl_opts  => { verify_hostname => 0 },
    );
    $client->ua($ua);
    return $client;
}

class_has _url => (
    is  => 'rw',
    isa => 'Str',
);

class_has _params_spec => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { return {} },
);

sub params_spec {
    given ($#_) {
        when (0) { return $_[0]->_params_spec() }
        when (1) { return $_[0]->_params_spec()->{ $_[1] } }
        when (2) {
            $_[0]->_params_spec()->{ $_[1] } = $_[2];
            return;
        }
        default {
            croak 'excess arguments in spec';
        }
    }
}

sub rpc_methods { keys %{ shift->_params_spec() } }

sub build_rpc_method {
    my ( $name, %spec ) = @_;
    return sub {
        my ( $self, @args ) = @_;

        if ( $self->has_state_params() ) {
            while ( my ( $param, $value ) = each %{ $self->state_params() } )
            {
                push @args, $param, $value;
                $spec{$param} = 1;
            }
        }

        my %params = validate( @args, \%spec );
        my $result = $self->rpc_client()->call(
            $self->rpc_url(),
            {
                method => $name,
                params => \%params,
            },
        );
        if ( !$result ) {
            croak $self->rpc_client()->status_line();
        }
        if ( !$result->is_success() ) {
            if ( reftype( $result->error_message() ) ~~ 'HASH' ) {
                ouch(
                    $result->error_message()->{code},
                    $result->error_message()->{message},
                );
            }
            else {
                croak $result->error_message();
            }
        }
        return $result->result();
    };
}

sub make_rpc_method {
    my ( $class, $name ) = @_;
    my $spec_ref = $class->params_spec($name) || croak "no spec for $name";

    {
        no strict 'refs';
        my $fq_name = $class . '::' . $name;
        *{$fq_name} = build_rpc_method( $name, %$spec_ref );

        my $decamelized_name = decamelize($name);
        if ( $name ne $decamelized_name ) {
            *{ $class . '::' . $decamelized_name } = \&{$fq_name};
        }
    }

    return;
}

sub make_rpc_methods { $_[0]->make_rpc_method($_) for $_[0]->rpc_methods() }

1;

__END__

=head1 SYNOPSIS

    package My::Service::Client;
    use JSON::RPC::Client::Spec;
    use Params::Validate ':all';

    url 'http://www.example.com/jsonrpc/API';

    spec sum => {
        a => { type => SCALAR },
        b => { type => SCALAR },
    };

    spec echo => {
        msg => { type => SCALAR, optional => 1 },
    };

    1;

    # Somewhere in other packages

    my $client = My::Service::Client->new(
        username => 'myuser',                   # optional user and pass
        password => 'mysecret',                 # for HTTP Basic auth
        static_params => {                      # optional static params to be
            roles => { myrole => 'mysecret' },  # passed to every request
        },
    );

    # or just

    my $client = My::Service::Client->new();    # no auth, no static params

    my $sum = $client->sum( a => 20, b => 30 );
    my $rv  = $client->echo( msg => 'Zdravstvuy Mir!' );

=method spec $name, %spec

Set specification for parameters of method $name in Params::Validate format
and build sub with specified $name.

=method url $url

Set the URL of JSON-RPC service.

=head1 SEE ALSO

    Params::Validate

