#
# Copyright (c) 2018 cPanel, L.L.C.
# All rights reserved.
# http://cpanel.net/
#
# Distributed under the terms of the MIT license.  See the LICENSE file for
# further details.
#
package OpenStack::Client::Auth::v3;

use strict;
use warnings;

use OpenStack::Client ();

sub new ($$%) {
    my ( $class, $endpoint, %args ) = @_;
    my %request;
    unless ( $args{'request'} || $args{'token'} ) {
        unless ( defined $args{'username'} || defined $args{'user_id'} ) {
            die 'No OpenStack username or user_id provided in "username" or "user_id".\n';
        }
        die 'No OpenStack password provided.\n' unless defined $args{'password'};
        $args{'domain'} ||= 'default';
    }

    my $client = OpenStack::Client->new(
        $endpoint,
        'package_ua'       => $args{'package_ua'},
        'package_request'  => $args{'package_request'},
        'package_response' => $args{'package_response'}
    );

    if ( $args{'password'} ) {
        %request = (
            'auth' => {
                'identity' => {
                    'methods'  => [qw(password)],
                    'password' => {
                        'user' => {
                            'password' => $args{'password'},
                        }
                    }
                }
            }
        );

        if ( $args{'username'} ) {
            # Take a ref.
            my $user_ref = $request{'auth'}->{'identity'}{'password'}{'user'};
            $user_ref->{'name'} = $args{'username'}; 
            # $domain{'name'} is 'Default' in the most general case. $domain{'id}, is 'default'.
            # In the case that someone had modiifed $ddomain{'name'}, it's 
            $user_ref->{'domain'} = { 'id' => $args{'domain'} };
        }
        elsif ( $args{'user_id'} ) {
            $request{'auth'}->{'identity'}{'password'}{'user'} = { 'id' => $args{'user_id'} };
        }
    }
    elsif ( $args{'token'} ) {
        %request = (
            'auth' => {
                'identity' => {
                    'methods' => [qw(token)],
                    'token'   => { 'id' => $args{'token'} },
                },
            }
        );
    }
    elsif ( $args{'request'} ) {
        %request = %{ $args{'request'} } if $args{'request'};
    }

    $request{'auth'}->{'scope'} = $args{'scope'} if defined $args{'scope'};
    my $response = $client->request(
        'method' => 'POST',
        'path'   => '/auth/tokens',
        'body'   => \%request,
    );

    my $body = $response->decode_json;

    unless ( defined $response->header('X-Subject-Token') ) {
        die 'No token found in response headers';
    }

    unless ( defined $body->{'token'} ) {
        die 'No token found in response body';
    }

    unless ( defined $body->{'token'}->{'catalog'} || $args{'request'} ) {    # You probably already know this if you're using an auth object.
        warn "No catalog found in the token object. You probably have an unscoped token.\n You won't be able to access other service endpoints.\n";
    }

    return bless {
        'package_ua'       => $args{'package_ua'},
        'package_request'  => $args{'package_request'},
        'package_response' => $args{'package_response'},
        'response'         => $response,
        'body'             => $body,
        'clients'          => {},
        'services'         => $body->{'token'}->{'catalog'}
    }, $class;
}

sub body ($) {
    shift->{'body'};
}

sub response ($) {
    shift->{'response'};
}

sub access ($) {
    shift->{'body'}->{'access'};
}

sub token ($) {
    shift->{'response'}->header('X-Subject-Token');
}

sub services ($) {
    my ($self) = @_;

    my %types = map { $_->{'type'} => 1 } @{ $self->{'services'} };

    return sort keys %types;
}

sub service ($$%) {
    my ( $self, $type, %opts ) = @_;

    if ( defined $self->{'clients'}->{$type} ) {
        return $self->{'clients'}->{$type};
    }

    if ( defined $opts{'uri'} ) {
        return $self->{'clients'}->{$type} = OpenStack::Client->new(
            $opts{'uri'},
            'package_ua'       => $self->{'package_ua'},
            'package_request'  => $self->{'package_request'},
            'package_response' => $self->{'package_response'},
            'token'            => $self->token
        );
    }

    $opts{'endpoint'} ||= 'public';

    if ( $opts{'endpoint'} !~ /^(?:public|internal|admin)$/ ) {
        die 'Invalid endpoint type specified in "endpoint"';
    }

    foreach my $service ( @{ $self->{'services'} } ) {
        next unless $type eq $service->{'type'};

        foreach my $endpoint ( @{ $service->{'endpoints'} } ) {
            next if defined $opts{'id'}       && $endpoint->{'id'} ne $opts{'id'};
            next if defined $opts{'region'}   && $endpoint->{'region'} ne $opts{'region'};
            next if defined $opts{'endpoint'} && $endpoint->{'interface'} ne $opts{'endpoint'};

            return $self->{'clients'}->{$type} = OpenStack::Client->new(
                $endpoint->{'url'},
                'package_ua'       => $self->{'package_ua'},
                'package_request'  => $self->{'package_request'},
                'package_response' => $self->{'package_response'},
                'token'            => $self->token
            );
        }
    }

    die "No service type '$type' found";
}

1;
