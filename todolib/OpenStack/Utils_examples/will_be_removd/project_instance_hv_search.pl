#!/usr/bin/perl

package poc_scripts::servers_key_sort;

use warnings;
use strict;
use FindBin;
use JSON;
use Term::ReadKey;

use Data::Dumper;

use lib qq{$FindBin::Bin/../todolib/};


use qq{OpenStack::Client::Utils};

__PACKAGE__->run(@ARGV) unless caller;

=pod

=head1 Name:

servers_key.pl

=head1 Description:

A quick script which utilizes OpenStack::Utils and OpenStack::Client to retrive
all instances filtered on project.

This script demonstrates how to use OpenStack::Utils to easily make API
requests.

=head1 TODO:

=over 2

=item E<0x2610>

Read credentials from local file for now.

=item E<0x2610>

Improve the modulino pattern.

=item E<0x2610>

Read request methods from file.

=back

=head2 main()

The main logic of the script.

=cut

# request: path, service, method, body (not get methods), optional labels

sub run {
    my $args = @_;

    my $server_list_request = {
        'label'   => 'servers.list.brief',
        'service' => 'compute',
        'method'  => 'GET',
        'path'    => '/servers',
    };

    my %proj_scope_args = (
        'project_name' => '',
        'type'         => 'project'
    );

    my $project_name = 'dan.stewart@cpanel.net';

    $proj_scope_args{'project_name'} = $project_name;

    my $password   = prompt_for_input("Password for initial API authentication: ");
    my %initial_auth = auth_boilerplate( 
        'scope' => \%proj_scope_args, 
        'password' => $password 
    );

    my %system_scope_token_auth = auth_boilerplate(
        'scope'   => { 'type' => 'system' },
    );

    ### Setup for object instantiation and first call.

    # my $project_name = prompt_for_input("Input project name for project scoped requests: ", 1);
    ## Initial request.
    my $os_util     = OpenStack::Client::Utils->new(%initial_auth);
    my $sl_response = $os_util->request($req);

    ### Scope for next call.

    $os_util->set_auth(%system_scope_token_auth);

    ### Follow the individual server detail paths to get at the hypervisor information.
    my $response_collection = [];
    foreach my $server ( @{ $sl_response->{'servers'} } ) {
        # Add server details to  collection.
        my %sd_request = %{$req};
        $sd_request{'path'}  = "/servers/" . $server->{'id'};
        $sd_request{'label'} = "server.details";

        ### Collect the server details.
        push @$response_collection, $os_util->request( \%sd_request );
    }
    my $hv_hr;
    foreach my $sd_response (@$response_collection) {
        my $hypervisor = $sd_response->{'server'}->{'OS-EXT-SRV-ATTR:hypervisor_hostname'};
        $hv_hr->{$hypervisor} = [ ];
        push @{$hv_hr->{$hypervisor}}, { 'name' => $sd_response->{'server'}{'name'} };
    }
    my $json             = JSON->new( );
    my @arr;
    foreach my $hv_key ( keys %$hv_hr ) {
        print Dumper $hv_hr->{$hv_key};
        push @arr, ({ $hv_key => $hv_hr->{$hv_key} });
    }
    my $hv_json = encode_json \@arr;
    print $hv_json;
}

sub auth_boilerplate {
    my %args = @_;
    my %fwd_args;
    if ( exists $args{'password'} && defined $args{'password'} ) {
        $fwd_args{'password'} = $args{'password'};
        if ( exists $args{'username'} && defined $args{'username'} ) {
            $fwd_args{'username'} = $args{'username'};
        }
        elsif ( exists $args{'user_id'} && defined $args{'user_id'}) {
            $fwd_args{'user_id'} = $args{'user_id'};
        }
        else {
            $fwd_args{'username'} = 'admin';
        }
    }
    elsif ( exists $args{'token'} && defined $args{'token'} ) {
        $fwd_args{'token'} = $args{'token'};
    }
    if ( exists $args{'scope'} && defined $args{'scope'} ) {
        $fwd_args{'scope'} = $args{'scope'};
    }
    return (
        'auth_endpoint' => 'https://service01a-c2.cpanel.net:5001/',
        'auth_version'  => '3',
        %fwd_args
    );
} 

sub prompt_for_input {
    my $prompt_phrase = shift;
    my $echo = shift;
    Term::ReadKey::ReadMode 'noecho' if !$echo;
    print $prompt_phrase;
    my $input = Term::ReadKey::ReadLine(0);
    Term::ReadKey::ReadMode('restore');
    print "\n";
    $input =~ s/\R\z//;
    return $input;
}
