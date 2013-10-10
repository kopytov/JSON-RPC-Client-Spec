# NAME

JSON::RPC::Client::Spec - JSON-RPC client with methods specifications

# VERSION

version v0.1

# SYNOPSIS

    package My::Service::Client;
    use JSON::RPC::Client::Spec;
    use Params::Validate ':all';

    url 'http://www.example.com/jsonrpc/API';

    spec sum => (
        a => { type => SCALAR },
        b => { type => SCALAR },
    );

    spec echo => (
        msg => { type => SCALAR, optional => 1 },
    );

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

# METHODS

## spec $name, %spec

Set specification for parameters of method $name in Params::Validate format
and build sub with specified $name.

## url $url

Set the URL of JSON-RPC service.

# SEE ALSO

    Params::Validate

# AUTHOR

Dmitry Kopytov <kopytov@webhackers.ru>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Dmitry Kopytov.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
