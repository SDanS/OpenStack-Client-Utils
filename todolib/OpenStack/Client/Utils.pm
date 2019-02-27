package OpenStack::Client::Utils;

use strict;
use warnings;
use JSON;
use Data::UUID;
use OpenStack::Client::Auth;
use Scalar::Util;

use Data::Dumper;

use strict;
use warnings;

=pod 

=encoding utf8

=head1 NAME

OpenStack::Client::Utils - A set of utility methods to accomplish common tasks on OpenStack utilizing OpenStack::Client

=back

=head1 DESCRIPTION

A set of utility methods to accomplish common tasks on OpenStack utilizing OpenStack::Client.

=head1 INSTANTIATION

=head2 C<OpenStack::Utils-E<gt>new()>

E<10>

=head3 B<Simple Use case>

E<10>

    my $auth = {
        # Defaults to 3.
        'version' => 3,
        'endpoint' => 'https://bigreddog.namedclifford.com:5001/'
        'tenant' => $project_name,
        'username' => $username,
        'password' => $password,
    };

    $auth->{'scope'} = {
        'project' => {
            'name'   => 'someproject',
            'domain' => { 'name' => 'default' },
        },
    };

=item B<OR>

If you're only making a single request, pass the scope object that is required.

    my $auth = {
        'auth_endpoint' => 'https://bigreddog.namedclifford.com:5001/',
        'request_body' => {
            'auth => {
                'identity' => {
                    'methods' => [ 'password' ],
                    'password' => {
                        'user' => {
                            'password' => '<password>',
                            'domain' => {
                                'name' => 'default'
                            },
                            'name' => 'admin'
                        }
                    } 
                }
                'scope' => {
                    'project' => {
                        'name'   => 'someproject',
                        'domain' => { 'name' => 'default' },
                    },
                },
            },
        },
    };

    my $request = {
        'method' => 'GET',
        'path' => '/servers/detail',
    };

=item B<Some callers or users may be admins.>

E<10>

    $request->{'body'} = {
        'all_tenants' => '1',
        'project_id' => 'bluedog@bigreddog.namedclifford.com',
    };    

    
=item B<Inital authentication and client creation;

E<10>

    my $os_util = OpenStack::Utils->new($auth);
    $os_util->set_service_client('compute');

=item B<OR>

    $request->{'service'} = 'compute';

    # If you didn't set your scope at object instantiation with the authentication object:

    $request->{'auth'}->{'scope'} = {
        'project' => {
            'name'   => 'someproject',
            'domain' => { 'name' => 'default' },
        },
    };

    $os_util->request($request);



=item B<Pass an authentication scope in your request object.>

If scope needs to be set after initial autheniation for subsequent requests,
one can pass it as an auth scope object in the request object. 
If this is the first request after instantiation and a scope was not set at
instantiation, you should add a password method authentication object to the 
call to $os_util->request(). 

E<10>

    my $request = { . . . };

    $request->{'auth'}->{'scope'} = {
        'project' => {
            'domain' => {
                'name' => "default",
            },
        'name' => $project_name,
        },
    };

=item B<OR>

    $request->{'auth'}->{'scope'} = {
        'system' => { 
            "all" => 'true' 
        },
    },

=item $request object can store data for processing the response.

Since it's passed to the response handler, you can add arbitrary keys and
values to the request for handling in a subclass. See examples/Util_examples/
subclass_libs/Intercept.pm. Complex handling and filtering can be performed on 
collections of responses using this technique.

    $request->{'label'} = 'hypervisor-server-search-project';

See example/Utils_example/subclass_libs/Intercept.pm and the corresponding get_server_hv.pl


=cut

sub new {
    my $class = shift;
    my %auth  = @_;
    my $self  = {};
    print Dumper $self;
    print Dumper $class;

    bless $self, $class;
    ### Set scope for first request.

    $self->set_auth( \%auth ) unless $auth{'no_auto'};
    return $self;
}

=head1 B<PUBLIC OBJECT INSTANCE METHODS>

=head2 Name: B<set_auth>

=head3 Usage: 

    $self->set_auth($auth);

=item B<Description:>

Authenticates and sets $self->{'auth'} to the returned authentication object 
making C<$os_util-<gt>set_service_client> and $self->{'auth'}->token()
available.

=head3 Arguments:

=item auth_endpoint B<REQUIRED>

=item version (defaults to 3)

=item A full auth request object at C<%auth{'auth_request_body'}>

Such an object can be constructed using set_auth_request_identity and 
set_auth_request_scope. Or one can be crafted externally.

    (
        'auth_endpoint' => <endpoint>,
        'auth_version'  => 3<default>|2,
        'auth_request_body' => {
            'auth' => {
                'identity' => {
                    ...
                },
                'scope' => {
                    ...
                }
            }
        }
    )

=item username, password, and domain.

You can pass this combination. Domain is set to default if not specified.

    (
        'username' => <username>,
        'password' => <password>,
        'domainname'    => <domainname>,

            B<OR>
        
        'domainid' => '<domainid>'

    )

=item user_id, password

You get the gist.


=back

=cut

sub set_auth {
    my $self = shift;
    my $auth = shift;
    my $auth_args;
    $auth = $self->auth_overrides( $auth );

    if ( exists $auth->{'auth_request_body'} ) {
        $auth_args->{'request'} = %{ $auth->{'auth_request_body'} };
    }
    else {
        my $scope = $auth->{'scope'};
        ( $scope, undef ) = $self->set_auth_request_scope($scope);
        
        my $version = $auth->{'version'}    #
          ? $auth->{'version'} : '3';

        die "authurl must be defined for authentication to be successful.\n" if !$auth->{'authurl'};
        my $endpoint = $auth->{'authurl'} . "v" . $auth->{'auth_version'};
        
        if ( $auth->{'token'} ) {
            $auth_args->{'token'} = $auth->{'token'};
        }

        elsif ( exists $auth->{'password'} && $auth->{'password'} ) {
            $auth_args->{'password'} = $auth->{'password'};
            
            ### Opportunity for common logic between project, domain, and user
            ### with regard to the (id|name) dilemna.
            if ( $auth->{'username'} ) {
                $auth_args->{'username'} = $auth->{'username'};
                for my $key ($auth) {
                    my ($type) = $key =~ /\bdomain(.*)\b/;
                    $auth_args->{ "domain" . $type } = $auth->{ "domain" . $type } if $type;
                    last if $type;
                }
            }
            elsif ( $auth->{'userid'} ) {
                $auth_args->{'userid'} = $auth->{'userid'};
            }
        }
        else {
            $auth_args->{'token'} = $self->{'auth'}->token() or die "Cannot find an authentication method.\n";
        }

        $auth_args->{'scope'}   = $scope if ref $scope eq "HASH";
        $auth_args->{'version'} = $version;
        $self->{'auth'}         = OpenStack::Client::Auth->new(
            $endpoint,
            %$auth_args,
        );
        return $self;
    }
}

=head2 Name: B<request>

=head3 Usage: C<$self-<gt>request($request, $auth)>

=item B<Description>

=over 2

Send the request using OpenStack::Client::call().

Selects the appropriate OpenStack::Client using set_service_client.

=item Response handlers and the request payload.

Another interesting point about the request object is that it can carry information
about how the response should be handled as it is passed to the response handler
method which can easily be overriden in a subclass. 

Example:

C<$request-<gt>{'label'} = 'hypervisor-server-search'>

See example/Utils_example/subclass_libs/Intercept.pm and the corresponding get_server_hv.pl

=item Request object:

{
    # Service needed for the request.
    'service' => 'compute',
    'method' => 'GET',
    'path' => '/servers/detail',
    'body' => { 
        '<body details>'
    },
}


=back

=cut

sub request {
    my $self    = shift;
    my $request = shift;
    $request = $self->request_override($request);
    $self->set_service_client( $request->{'service'} );
    my $response = $self->{'service_client'}->call($request);
    $response = $self->response_handler( $response, $request );
    return $response, $request;
}

=head2 Name: B<set_service_client>

=head3 Usage: C<$os_util-<gt>set_service_client($new_service_name)

=item B<Description> 

Sets the service used. Examples: "compute", "identity", "image", etc.

=cut

sub set_service_client {
    my $self    = shift;
    my $new_svc = shift;
    $self->{'service_client'} = $self->{'auth'}->service($new_svc);
    return $self;
}

=head2 Name: set_auth_identity

=head3 Usage: C<$os_util-<gt>set_auth_identity(\%args,$auth)>

=head3 Arguments:

Arguments should take one of the following forms:

{
    'auth_endpoint' => '<identity service endpoint'>,
    'auth_version'  => '3<default>|2'
}
=item Password authentication:

    {
        'username' => '<openstack login>',
        'userid'   => '<user id>'
        'password' => '<OpenStack password>',
        # Defaults to 'default'.

=item Domain is necessary when using username instead userid. 

        'domain_name => '<domain name>',

            B<OR>

        'domain_id'  => '<domain id> | default',
    }

=item Token authentication:

A token can be provided. If not provided and a successful authentication has
already occurred for the active user, it will be retrieved from the auth object.

    { 'token_id' => '<token_id>' | $self->{'auth'}->token() }

=item Description:

Convenience method to build the auth request body. This only creates the body
with the identity portion. For the scope portion see C<set_scope()>.

=cut

sub set_auth_request_identity {
    my $self = shift;
    my $args = shift;
    my %args = %{$args};
    my $auth = shift;
    if ( !$args{'password'} || !$args{'username'} ) {
        if ( !$args{'token'} ) {
            if ( !$self->{'auth'}->token() ) {
                die "No password/username combination or token available to authenticate.";
            }
        }
    }
    $auth->{'authurl'} = $args{'authurl'};
    $auth->{'version'} = $args{'version'} || '3';
    $auth->{'auth_request_body'}{'auth'}{'identity'} = { 'methods' => [] };
    my $identity = $auth->{'auth_request_body'}{'auth'}{'identity'};
    if ( $args{'password'} ) {
        my $user = $identity->{'password'}{'user'} = {};
        $identity->{'methods'} = ['password'];
        $user->{'password'}    = $args{'password'};

        if ( $args{'username'} ) {
            $user->{'name'} = $args{'username'};
            for my $key (%args) {
                my ($type) = $key =~ /\bdomain(.*)\b/;
                $auth->{ "domain" . $type } = $args{ "domain" . $type };
                last if $type;
            }
        }
        elsif ( $args{'userid'} ) {
            $user->{'id'} = $args{'user_id'};
        }
    }
    else {
        if ( $args{'tokenid'} ) {
            $identity->{'token'}{'id'} = $args{'tokenid'};
        }
        elsif ( $self->{'auth'}->token() ) {
            $identity->{'token'}{'id'} = $self->{'auth'}->token();
        }
        $identity->{'methods'} = ['token'];
    }

    return $auth->{'auth_request_body'}, $auth;
}

=head2 Name: set_scope()

=head3 Usage: C<$self-<gt>set_scope(\%args)>

=item B<Description>: Allows setting the scope and user for requests.

Authenticates to either change scope with an existing token after object 
instantiation or set scope on the initial request when there is not an existing
token.

If an $auth object is supplied to this method, that will take precendence over any 
existing token to allow user switching as well.

=head3 Arguments:

    { type => 'project' | 'domain' | 'system' }

=item System scope: 

Specifying the system type is sufficient for a system scoped token if the
authenticating user have the necessary roles.

=item Project scope:

If the project name is used, the domain name or id must also be specified. In 
many situations that domain id is 'default'. This will be "guessed" in the
situation that a domain name or id is not provided but C<$args{'project_name'}>
is. A project id is enough to definitively define a project for scoping. So,
in the event that C<$args{'project_id'}> is provided and no domain is, no
action will be taken to define the domain.

=over 4

=item Project name is specified.

The domain id will be set to 'default' if no domain name or domain id is
provided with project name.

    {
        'project_name' => '<project name>',
        'domain_id' => '<domain id>',

            B<OR>

        'domain_name' => '<domain name>'
    }

=item Numeric project id is specified.

    {
        'project_id' => '<project id>'
    }

=back

=item Domain Scope:

If neither domain_id or domain_name are defined, domain id will be set to 
'default'.

    { 'domain_id' => '<domain id>' }

        B<OR>

    { 'domain_name' => '<domain name>' }
    
=cut

sub set_auth_request_scope {
    my $self          = shift;
    my $scope_arg_ref = shift;
    print Dumper $scope_arg_ref;
    my $auth_ref = shift;
    my $auth     = $auth_ref ? $auth_ref : {};
    my %args     = %{$scope_arg_ref};

    # Take a ref.
    my $scope_ref = $auth->{'auth_request_body'}{'auth'}{'scope'} = {};
    if ( !$args{'type'} ) {
        die "Scope type must be defined.\n" . __PACKAGE__ . "::set_auth_request_scope\nFile: " . __FILE__ . " line: " . __LINE__ . "\n";
    }
    if ( $args{'type'} eq 'system' ) {
        $scope_ref->{'system'}{'all'} = JSON::true;
    }
    elsif ( $args{'type'} eq 'domain' ) {

        # Take a ref.
        my $s_domain = $scope_ref->{'domain'} = {};
        $s_domain = _set_domain_scope( $s_domain, \%args );
    }
    elsif ( $args{'type'} eq 'project' ) {
        $scope_ref = _set_project_scope( $scope_ref, \%args );
    }
    else {
        die "Unknown scope type: $args{'type'}.\n";
    }
    return $scope_ref, $auth;
}

=head2 Internal helper functions for set_auth_request_scope.

=head3 Name _set_domain_scope.

This shouldn't be directly accessed. 

=cut

sub _set_domain_scope {
    my $s_domain = shift;
    my %args     = shift;
    if ( !$args{'domainname'} && !$args{'domainid'} ) {
        $s_domain->{'id'} = 'default';
    }
    $s_domain->{'name'} = $args{'domainname'} if $args{'domainname'};
    $s_domain->{'id'}   = $args{'domainid'}   if $args{'domainid'};
    return $s_domain;
}

=head3 Name: _set_project_scope

This shouldn't be directly accessed. 

=cut

sub _set_project_scope {
    my $scope_ref = shift;
    my $arg_ref   = shift;
    my %args      = %{$arg_ref};
    if ( !$args{'projectname'} && !$args{'project_id'} ) {
        die "projectname or projectid must be defined for project scope type.\n";
    }
    if ( $args{'projectname'} ) {

        # Take a ref.
        my $p_domain = $scope_ref->{'project'}{'domain'} = {};
        $scope_ref->{'project'}{'name'} = $args{'projectname'};
        if ( $args{'domainname'} ) {
            $p_domain->{'name'} = $args{'domainname'};
        }
        elsif ( $args{'domainid'} ) {
            $p_domain->{'id'} = $args{'domainid'};
        }
        else {
            $p_domain->{'id'} = 'default';
        }
    }
    elsif ( $args{'projectid'} ) {
        $scope_ref->{'project'}{'id'} = $args{'projectid'};
    }
    return $scope_ref;
}

=head1 B<REQUEST OVERRIDES>

This is a placeholder for subclass overrides to do work on the request.

See example/Utils_example/subclass_libs/Intercept.pm and the corresponding get_server_hv.pl

=head2 Arugments 2

=item The Utils object.

=item The full request object.

=cut

sub request_override { return $_[1]; }

=head1 RESPONSE HANDLER.

This is a placeholder for subclass overrides to do work on the response.

See example/Utils_example/subclass_libs/Intercept.pm and the corresponding get_server_hv.pl

=head2 Arguments 3

=item The Utils object.

=item The response object.

=item The request object.

=cut

sub response_handler { return @_; }

=head1 AUTHENTICATION OVERRIDES

This is a placeholder for subclass overrides to do work on the authentication object.

See example/Utils_example/subclass_libs/Intercept.pm and the corresponding get_server_hv.pl

=head2 Arguments 2

=item The Utils object

=item The authentication object.

=cut

sub auth_overrides { shift; return @_; }

sub auth_post_actions { shift; return @_; }
1;
