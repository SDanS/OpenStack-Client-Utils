#!/usr/bin/perl

package OpenStack::Client::Utils::Utility;

use Storable 'dclone';
use warnings;
use strict;
use FindBin;
use JSON;
use Term::ReadKey;
use Getopt::Long;
use Scalar::Util;

use Data::Dumper;

use lib qq{$FindBin::Bin/../todolib/};

use base qq{OpenStack::Client::Utils};

my $debug = $cPOpenStack::ComputeRequests::debug = 1;

__PACKAGE__->new(@ARGV) if !caller;

=pod

=head1 Name:

compute_require.pl

=head1 Description:

A quick script which utilizes OpenStack::Utils and OpenStack::Client to retrive
all instances filtered on project.

This script demonstrates how to use OpenStack::Utils to easily make API
requests.

=head2 main()

The main logic of the script.

=head1 OBJECT INSTANTIATION:

=head2 Name: new()

=head2 Usage: 

    require('/path/to/compute_request.pl');


    cPOpenStack::ComputeRequests->new(

=item Scope

        'scope' => {
            'type' => 'project',
            'projectname' => '<the name>',
            'domainname'  => 'the name of the domain',

                B<OR>

            'domainid'    => 'the id of the domain'
        }

                B<OR>
            
        'scope' => {
            'type' => 'project',
            'projectid' => 'the id'

        }

                B<OR>
        
        'scope' => {   type' => 'system'   }

=item Identity:

You can pass this combination. Domain is set to default if not specified.


        'username' => <username>,
        'password' => <password>,
        'domainname' => <domainname>,
            
            B<OR>
    
        'domainid' => '<domainid>'

            B<OR>

        Use the user id for greater scpecificity.

        'userid' => '<userid>',
        'password' => <password>

            B<OR>

        'token' => '<token>'

Provide the identity endpoint;

        'authurl' => '<auth_url>'

Look ma! No domain!

=cut 

sub new {
    my $class = shift;
    my %args  = @_;
    my $self  = {};
    print __LINE__ . ": ";
    # tidyoff
    print  "New object %args: \n" if $debug; print Dumper \%args if $debug;
    # tidyon

    my (
        $password,     $username,     $domainid,   $domainname,
        $token,        $authurl,      $scope_args, $req_path,
        $req_service,  $req_body,     $method,     %request,
        $use_env_auth, $force_reauth, $pw_in_tracking,
    );


    $args{' use_env_auth '} //= \$use_env_auth;
    $args{'pw_in_tracking'} //= \$pw_in_tracking;
    $args{' password '}     //= \$password;
    $args{' username '}     //= \$username;
    $args{' domainid '}     //= \$domainid;
    $args{' domainname '}   //= \$domainname;
    $args{' token '}        //= \$token;
    $args{' authurl '}      //= \$authurl;
    $args{' scope '}        //= ( $scope_args = {} );
    $args{' debug '}        //= \$cPOpenStack::ComputeRequests::debug;
    $request{' path '}      //= \( $req_path = {} );
    $request{' service '}   //= \$req_service;
    $request{' body '}      //= \( $req_body = {} );
    $request{' method '}    //= \$method;

    if ( !caller ) {
        GetOptions(
            'username = s' => \$username,
            'password=s'   => \$password,
            'domainid=s'   => \$domainid,
            'domainname=s' => \$domainname,
            ### --scope type=project --scope username==<username> --password=<password>
            'scope=s'        => \$scope_args,
            'token=s%'       => \$token,
            'authurl=s'      => \$authurl,
            'service=s'      => \$req_service,
            'path=s'         => \$req_path,
            'body=s%'        => \$req_body,
            'method=s'       => \$method,
            'use_env_auth'   => \$use_env_auth,
            'pw_in_tracking' => \$pw_in_tracking,
            'force_reauth'   => \$force_reauth,

        );
    }

    $args{' use_env_auth '} = !!$use_env_auth | 1;
    $debug = $args{'debug'};
    %args = auth_from_env( $self, \%args ) if $args{'use_env_auth'};

    # tidyoff
    print __LINE__  . ":\n" . '%args prior to auth_boilerplate():' . "\n" if $debug; print Dumper \%args if $debug;
    # tidyon

    %args = auth_boilerplate( $self, \%args );

    # tidyoff
    print __LINE__ . ":\n" . '%args after auth_boilerplate():' . "\n" if $debug; print Dumper \%args if $debug;
    # tidyon

    $self = __PACKAGE__->SUPER::new(%args);
    set_auth_tracking( $self, \%args, ['from_new'] );

    # tidyoff
    print __LINE__ . "Self: \n" if $debug; print Dumper $self if $debug;
    # tidyon

    bless $self, $class;

    # tidyoff for DEBUG
    print "\n" . '%args: ' . "\n" if $debug; print Dumper \%args if $debug; print "\n" . '%request: ' . "\n" if $debug; print Dumper \%request if $debug; print "\n" if $debug;
    #tidyon

    bless $self, $class;
    $self->run( \%args, \%request ) if !caller;
    return $self;
}

=head1 AUTHENTICATION OVERRIDES

=cut

sub auth_overrides {
    my $self     = shift;
    my $auth     = shift;
    my %new_auth = dclone $auth;

    # tidyoff
    print __LINE__ . "; Inside auth_override.\n\n"; print Dumper $auth;
    # tidyon
     


    set_auth_tracking( $self, $auth, ['from_auth_overrides'] );
    print "\n\n\nNew_auth:::::\n\n"; print Dumper %new_auth; print Dumper \%new_auth;
    print "\n\n\nself:::::\n\n"; print Dumper $self;

    if ( grep{ $_ eq 'subs' }( keys %new_auth ) && ref $new_auth{'subs'} eq "ARRAY" ) {
        foreach ( @{%new_auth{'subs'}} ) {
            %new_auth = $_->( $self, %new_auth );
        }
    }

    print Dumper %new_auth;
    return %new_auth;
}

# Call it with no args to get scalar of $self->{'auth_tracking'}
# arrayref.
# ( <new/current param> @<keys for tracking and history>)

sub set_auth_tracking {
    my $self          = shift;
    my $auth          = shift;
    my $tracking_keys = shift;
    my @record_keys   = ( 'called_auths', @$tracking_keys );
    # tidyoff
    if ($debug) { print __LINE__ . ": auth: \n"; print Dumper $auth; print "\ntracking_keys:  \n"; print Dumper $tracking_keys; }
    # tidyon
    my %tracked_auth = dclone %{$auth};
    push @{ $self->{'auth_tracking'}->{$_} }, dclone %tracked_auth foreach @record_keys;
    return $self;
}

=head2 Here's your environmental variables.

      OS_PROJECT_DOMAIN_ID=dsefault
      OS_PROJECT_ID=09d4f0ab68e243eda5de26855b6636aa
      OS_REGION_NAME=RegionOne
      OS_USER_DOMAIN_NAME=Default
      OS_PROJECT_NAME=admin
      OS_IDENTITY_API_VERSION=3
      OS_PASSWORD=
      OS_AUTH_URL=https://service01a-c2.cpanel.net:5001/v3
      OS_USERNAME=admin
      OS_INTERFACE=public
      OS_TOKEN=     

=cut

sub auth_from_env {
    my $self;
    if ( !defined $_[0] && blessed $_[0] ) {
        $self = shift;
    }
    my $auth = shift;
    my $auth_args;

    $auth_args->{'version'} = $ENV{'OS_IDENTITY_API_VERSION'}    #
      ? $ENV{'OS_IDENTITY_API_VERSION'} : $auth->{'version'};

    $ENV{'OS_AUTH_URL'}
      ? ( $auth_args->{'authurl'} = $ENV{'OS_AUTH_URL'} ) =~ s/(.*\/)v\d/$1/
      : warn "No authurl found in environmental variables and auth_from_env was specified.\n"    #
      . "Perhaps you need to \`source\` your openstackrc file again. This Will probably fail.";

    $auth_args->{'domainid'} = $auth_args->{'scope'}{'domainid'} =
        $ENV{'OS_PROJECT_DOMAIN_ID'}
      ? $ENV{'OS_PROJECT_DOMAIN_ID'}
      : $auth->{'domainid'};

    $auth_args->{'domainname'} = $auth_args->{'scope'}{'domainname'} =
        $ENV{'OS_USER_DOMAIN_NAME'}
      ? $ENV{'OS_USER_DOMAIN_NAME'}
      : $auth->{'domainname'};

    $auth_args->{'projectid'} = $auth_args->{'scope'}{'projectid'} =
        $ENV{'OS_PROJECT_ID'}
      ? $ENV{'OS_PROJECT_ID'}
      : $auth->{'projectid'};

    $auth_args->{'username'} =
      $ENV{'OS_USERNAME'} ? $ENV{'OS_USERNAME'} : $auth->{'username'};

    $auth_args->{'projectname'} = $auth_args->{'scope'}{'projectname'} =
      $ENV{'OS_PROJECT_NAME'} ? $ENV{'OS_PROJECT_NAME'} : $auth->{'projectname'};    #

    $auth_args->{'token'}    = $ENV{'OS_TOKEN'}    ? $ENV{'OS_TOKEN'}    : $auth->{'token'};
    $auth_args->{'password'} = $ENV{'OS_PASSWORD'} ? $ENV{'OS_PASSWORD'} : $auth->{'password'};
    set_auth_tracking( $self, $auth_args, ['auth_from_env'] );
    return %$auth_args;
}

sub auth_post_actions {
    my $self = shift;
    my $auth = shift;
    $self->set_token($auth);

    return $auth;
}

sub set_token {
    my $self = shift;
    my $auth = shift;
    $auth->{'token'} = $ENV{'OS_TOKEN'} =
        $self->{'auth'}->token()
      ? $self->{'auth'}->token()
      : warn "Failed to retrieve token for storage in environment variable. You will need to\n"    #
      . "athenticate with credentials before you next change scope. Additionally, there may\n"     #
      . "be a problem with Keystone.\n";
}

=head1 REQUEST OVERRIDES

=cut

sub request_override {
    my $self    = shift;
    my $request = shift;
    print "request_override!\n" if $debug;
    $request = $self->request_args($request);

    # tidyon
    print "Overridden request!\n" if $debug;
    print Dumper $request if $debug;
    # tidyoff
    return $request;
}

sub request_args {
    my $self = shift;
    my %args = @_;
    my $new_args =
        $args{'method'} == 'GET' || !$args{method} ? $self->get_request_args(%args)
      : $args{'method'} == 'POST'   ? $self->post_request_args(%args)
      : $args{'method'} == 'PUT'    ? $self->put_request_args(%args)
      : $args{'method'} == 'PATCH'  ? $self->patch_request_args(%args)
      : $args{'method'} == 'DELETE' ? $self->delete_request_args(%args)
      :                               die "How did we get here?!\n";
    print Dumper $new_args if $debug;
    return $new_args;
}

# Compute is assumed. We only need path and body at this point. Trying to provide
# as much shorthand and convenience as possible.

sub get_request_args {
    my $self = shift;
    my %req  = @_;
    $req{'service'} = "compute"                 if !$req{'service'};
    $req{'method'}  = 'GET'                     if !$req{'method'};
    $req{'body'}    = $self->request_body(%req) if $req{'body'};
    # tidyon
    print "Building request arguments in " . __PACKAGE__ . "::get_request_args().\n" . __FILE__ . "line: " . __LINE__ . "\n" if $debug;
    print Dumper \%req if $debug;
    # tidyoff
    return %req;

}

=head3 STUBS:

=cut

sub post_request_args { return $_[1]; }

sub put_request_args { return $; }

sub patch_request_args { return $_; }

sub delete_request_args { return $_; }

sub request_body { return $_; }

sub run {
    my $self    = shift if ref $_[0];
    my $args    = shift;
    my $request = shift;
    my %args    = %$args;
    my %request = %$request;

    ### Get options if !caller.
print Dumper caller;
    if ( !caller ) {
        my $project_name;
        my $password;
        $project_name = 'dan.stewart@cpanel.net';
        $args{'scope'} = { 'type' => 'project' };
        $args{'scope'}->{'projectname'} = $project_name;
        $password = prompt_for_input("Password for initial API authentication: ") if !caller;
        my %initial_auth = auth_boilerplate( 'authurl' => $args{'authurl'}, 'scope' => $args{'scope'}, 'password' => $password );
        my %system_scope_token_auth = auth_boilerplate( 'scope' => { 'type' => 'system' } );
        ## Initial request.
        my $self->new(%initial_auth);
        my $sl_response = $self->request( request_args( 'path' => '/servers' ) );
        ### Get token for new scope.
        $self->set_auth( auth_boilerplate( 'scope' => { 'type' => 'system' } ) );
        $self->instance_hypervisor_sort( $sl_response, 'OS-EXT-SRV-ATTR:hypervisor_hostname', ['name'], );
    }
}

sub response_handler {
    my $self        = shift;
    my $response    = shift;
    my $request     = shift;
    my $handled_res = dclone $response;
    if ( ref $request->{'response_handler'} eq "ARRAY" ) {
        foreach my $sub_and_args ( @{ $request->{'response_handler'} } ) {
            my $sub      = $sub_and_args->{'sub'};
            my $sub_args = $sub_and_args->{'args'};
            ( $handled_res, $request ) = $sub->( $self, $handled_res, $request, $sub_args );
        }
    }
    return $handled_res, $request;
}

sub value_concat {
    my ( $self, $response, undef, $sub_args ) = @_;
    my $attribute = $self->value_from_response( $response, $sub_args->[0]);
    my $request_path = placeholder( $sub_args->[1] );
    return $request_path;
}

sub request_collection {
    my $self        = shift;
    my $sub_args    = shift;
    my $authargs    = $sub_args->[0];
    my $requestargs = $sub_args->[1];
    my $collection;
    $self->set_auth( auth_boilerplate($authargs) );
    foreach my $request (@$requestargs) {
        push @$collection, $self->request( request_args(%$requestargs) );
    }
    return $collection;
}

sub placeholder {
    my $string     = shift;
    my $value      = shift;
    my $new_string = $string =~ s/\<.*\>/$value/;
    return $new_string;
}

sub value_from_response {
    my $response     = shift;
    my $sub_args     = shift;
    my $attr         = get_response_attribute( $response, $sub_args );
    return $attr if ref $attr ne "SCALAR";
    return $$attr ref $attr eq "SCALAR";
    warn "We didn't find a value or hash at path:\n"    #
        . "    \$response->{\"$_\"}";
    print "->{\"$_\"}" foreach @$sub_args;
    print "\n";
    return( die( "Let's not take any chances" ) );
}

sub get_response_attribute {
    my $response     = shift;
    my $sub_arg_arr     = shift;
    my $attr =
    ( exists $response->{$sub_arg_arr} &&  !ref $response->{$sub_arg_arr} )
      ? return $response->{$sub_arg_arr}        : scalar $sub_arg_arr->[0] == 1
      ? return $response->{ $sub_arg_arr->[0] } : ref $response->{$sub_arg_arr} =~ /ARRAY|HASH/
      ? walk_ref_path( $response, $sub_arg_arr ) : value_from_response( $response, $sub_arg_arr );

    return $attr;
}

sub walk_ref_path {
    my ( $res_ref_part ) = my ( $response_ref ) =
      ( ref $_[0] =~ /ARRAY|HASH/ ) ? shift : get_response_attribute( @_ );
        ###  =  my (  @$path_to_attr )
    my ( @next_steps)  = shift || value_from_response($res_ref_part, @_  );
    my @h_ref_collection;
    push my ( @all_refs ), $response_ref;
        if (
            ref $res_ref_part->{ $next_steps[ 0 ] } eq "HASH"
          ) {
            shift @next_steps;
            push @all_refs, walk_ref_path( $res_ref_part->{ $next_steps[0] }, \@next_steps );
        }
        elsif (
            exists $res_ref_part->{ $next_steps[0] } &&
            ref $res_ref_part->{$next_steps[0]} eq "ARRAY"
          ) {
            push @all_refs, arrays_of_hashes( $res_ref_part, \@next_steps );
        }
    return $all_refs[$#all_refs];
}

sub arrays_of_hashes {
    my ( $res_data ) = ref $_[0] eq "ARRAY" ? shift : get_response_attribute( @_ );
    my $next_steps = shift;
    my @nested_key_path = @$next_steps;
    my @item_refs;
        foreach my $stepped_data ( $#$res_data ) {
            if (
                exists $stepped_data->{ $nested_key_path[0] }   &&
                ref $stepped_data->{$nested_key_path[0]} ne "ARRAY"
            ) {
                push @item_refs, get_response_attribute( $stepped_data->{ $nested_key_path[0] },  )
            }
            else {
                shift @nested_key_path;
                my @arr_collection = arrays_of_hashes( $stepped_data->{$nested_key_path[0]}, \@nested_key_path );
            }
        }
    return \@item_refs;
}

sub common_deref_path {
    my $paths = @_;
    my @paths = sort { scalar @$a <=> scalar @$b } @$paths;
    my @common_path;
    my %c_indexes;
    foreach my $index ( 0 .. $#{ $paths[0] } ) {
        foreach my $path_index ( 0 .. $#paths ) {
            if ( $paths[$path_index]->[$index] eq $paths[0]->[$index] ) {
                $c_indexes{$index}{'count'} += 1;
                if ( $index > 0 && $paths[$path_index]->[ $index - 1 ] eq $paths[0]->[ $index - 1 ] ) {
                    push @{ $c_indexes{$index}{'index_of_a_ref'} }, $paths[$path_index];
                }
            }
        }
    }
    my $common_step;
    my @shared_by_index;
    foreach my $index ( sort keys %c_indexes ) {
        push @common_path, $paths[0]->[$_] if scalar $c_indexes{$index}{'index_of_a_ref'} eq scalar @$paths[0];
        push @shared_by_index, $c_indexes{$index}{'index_of_a_ref'};
    }
    return \@common_path, \@shared_by_index;
}

sub cmp_array_length {

}

sub hr_step {
    my $hash_ref = shift;
    my $step     = shift;
    return $hash_ref->{$step};
}

sub auth_boilerplate {
    my $self = shift if scalar @_ == 2;
    my $args = shift;
    $args = dclone $args;
    my %fwd_args;
    
    # tidyoff for DEBUG
    print Dumper $args if $debug; print "In " . __PACKAGE__ . " ::auth_boilerplate()\n" . __FILE__ . " line: " . __LINE__ . "\n";
    # tidyon

    $fwd_args{'token'} = $args->{'token'}
      ? $args->{'token'}
      ### Don't fetch tokens if force_reauth is true.
      : ( $ENV{'OS_TOKEN'} )    # tidyoff
      ? $ENV{'OS_TOKEN'}
      ### Don't fetch tokens if force_reauth is true.
      : ( !$args->{'force_reauth'} && $self->{'auth'} && $self->{"auth"}->token() )    #
      ? $self->{"auth"}->token()
      : undef;                                                                         # tidyon

    # tidyoff for DEBUG
    print "Inside token helper (auth_boilerplate())\nToken: " . !!($fwd_args{'token'}) ? $fwd_args{'token'} : '' . "\nIn " . __PACKAGE__ . "::auth_boilerplate()\n" . __FILE__ . " line: " . __LINE__ . "\n" if $debug;
    # tidyon

    if ( !$fwd_args{'token'} && exists $args->{'password'} && defined $args->{'password'} ) {
        $fwd_args{'password'} = $args->{'password'};
        if ( exists $args->{'$'} && defined $args->{'username'} ) {
            $fwd_args{'username'} = $args->{'username'};
        }
        elsif ( exists $args->{'userid'} && defined $args->{'userid'} ) {
            $fwd_args{'userid'} = $args->{'userid'};
        }
        else {
            $fwd_args{'username'} = 'admin';
        }

        # tidyoff
        print "Username and password helper. \n Password: " . !!($fwd_args{'password'}) ? $fwd_args{'password'} : '' . "\n" . "Username: " . !!($fwd_args{'username'}) ? $fwd_args{'username'} : '' . "\nUser id: " . $fwd_args{'userid'} . "\n" . "In " . __PACKAGE__ . "::auth_boilerplate()\n" . __FILE__ . " line: " . __LINE__ . "\n" if $debug;
        # tidyon

    }
    else { warn "No Authentication method specified for boilerplate. Assuming implicit token auth\nor no need to authenticate." }
    if ( exists $args->{'scope'} && $args->{'scope'} ) {
        $fwd_args{'scope'} = $args->{'scope'};
    }
    $fwd_args{'authurl'} = $args->{'authurl'} or die "authurl must be defined.\n";
    $fwd_args{'auth_version'} = $args->{'version'} ? $args->{'version'} : 3;

    # tidyon
    print "Inside authenticiation helper building auth arguments: \n"                             if $debug;
    print Dumper \%fwd_args                                                                       if $debug;
    print "In " . __PACKAGE__ . "::auth_boilerplate()\n" . __FILE__ . " line: " . __LINE__ . "\n" if $debug;
    # tidyoff

    return %fwd_args;
}

1;
