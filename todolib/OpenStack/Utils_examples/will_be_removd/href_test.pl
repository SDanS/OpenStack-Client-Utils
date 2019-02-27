#!/usr/bin/perl

# use strict;
use warnings;
use Data::Dumper;
{ 
    package BugaBuga;

    sub new () {
        my $class = shift;
        my $self = {};
        bless $self, $class;
        return $self;
    }

    sub hi {
        my $self = shift;
        my $arg = shift;
        print $arg . "\n";
    }
}

my @name_path = ( 'data', 'name' );

#my %friend = ( 'data' => { 'name' => 'joebob' } );

# my ($href, $temp_ref) = (\%friend, undef);
# $href = $temp_ref = $href->{$_} foreach ('data', 'name');
my $href = { 'data' => { 'name' => 'joebob' } };
my @hrefs = map { $href = $href->{$_}; } ( 'data', 'name' );

# print Dumper $href;
#print $href;
my %hash;
my $vref = '0000000000';
$hash{'hi'} = \$vref;

#print Dumper \@hrefs

# $vref = '88888888';
# print ${$hash{'hi'}};

# map { print $href . "Before" . "\n"; my $href = $_;  }

# my $test->{'arr'} = ['one', 'two', 'three' ];
# print Dumper $test;
# my $testarr = $test->{'arr'};
#
# my $first = shift(@$testarr);
# print Dumper $testarr;
# print Dumper $test;

my @arr = ( 'one', 'two', 'three' );

my @all_refs;

# push @all_refs, \@$arr_ref[$_ .. $#$arr_ref] foreach 0 .. $#$arr_ref;
# print Dumper @all_refs;

@all_refs = ();

@arr = ( @arr, 'four', 'five' );
my $arr_ref = \@arr;

my %ref = (

    ### Works
    max_index_ref    => \$#arr,
    max_index_of_ref => $#$arr_ref,
    ### Works
    max_index_of_direct_ref => $#[@arr],

    arr_ref                        => \@arr,
    arr_ref_to_elems               => [ @arr[ 0 .. $#arr ] ],
    arr_ref_to_elems_max_index_ref => [ @arr[ 0 .. $#$arr_ref ] ],
    arr_ref_to_elems2              => [@arr],
    arr_ref_to_ref_elems           => [@$arr_ref],

);

my %refs = (
    arr_ref_index     => $#{$arr_ref},
    arr_ref_index_ref => \$#{$arr_ref},
);

#print "\n\nOriginal array refs:\n\n";
#print_refs();
#
#print scalar @arr . "\n";
#
#print "\n\nAddding values to '@':\n\n";
#@arr = ( @arr, 'six', 'seven' );
#
#print_refs();
#
#print scalar @arr . "\n";
#
#print "\n\nTaking a slice of 'arr:\n\n";
#$arr_ref = [ @arr[ 2 .. $#$arr_ref ] ];
#print_refs();
#

my $a1 = [ 1, 2, 3, 4, 5 ];
my $a2 = [ 1, 2 ];
my $a3 = [ 1, 2, 3 ];
my $a4 = [ 1, 2, 3, 4 ];
my @arr_o_arr = ( $a1, $a2, $a3, $a4 );

my @sorted = sort { scalar @$a <=> scalar @$b } @arr_o_arr;

#print Dumper \@sorted;
#
#print scalar @$_ . "\n" foreach @sorted;

# sub print_refs {
#     foreach my $key (keys %ref) {
#         print "key: " . $key . "\n";
#         print "Dumper output for key: " . $key . "\n";
#         print Dumper $ref{$key};
#         print "\n";
#     }
# }

my @b = ( '1',      '2' );
my @c = ( 'deaky',  '2', '3', '4', '5' );
my @d = ( 'freaky', '1', '', '', 'hi' );
my @a = ( \@b, \@c, \@d );

# my %h = %a[ 0 .. $#a ];

# print Dumper \@{$a[2]};
#
# # print $#$[$a[2]];
#
# print Dumper $a[2];
# print Dumper \@{ $a[2] };
# print Dumper %@{$a[2]};
# # print Dumper %{ @{ $a[2] } };
#
# print ( scalar @{$a[2]} );
# # my @a = @$a;
# my @firstarr = @{$a[2]};
#
# # Works
# my %h = %{ @a[0] }[ 0 .. $#{ @a[0] } ];
# print Dumper \%h;
# my @max_common = ( 0 .. $#a );
# my $max_index = $#a;

my @count_array = @a[ 0 .. $#a ];

# my @crazy =  ( @{@a[ 0 .. $#a ]});

# my %h = { };

#
# my @hi = ( 'hi' x ($#{ $a[0] } + 1));
# print @hi;
my %nh;
map {
    my $a_ref = $_;
    # print Dumper $a_ref;
    map {
        if ( $a_ref->[$_] eq $a[0]->[$_] ) {
            $nh{$_}{'count'}++;
            push @{ $nh{$_}{'paths sharing'} }, $a_ref;
        }
    } ( 0 .. $#{ $a[0] } );
} @a;

# my %nh = %{ [ ( 'hi' x ( $#{ $a[0] } + 1 ) ) ] }[ 0 .. $#{ $a[0] }];
# print Dumper \%nh;

# my %ct_h = map {
#     my %empty = ();
#     %empty = %{ ('' x $#{ $a[0] } )[ 0 ..$#{ $a[0] } ] };
#     print Dumper \%empty;
# } @count_array;
# foreach my $ref (@crazy) {
# }

# print Dumper \@crazy;
# my %elem_array = %{ @{ $_ }[0] } }[ 0 .. $#{ @a[0]} ];

# print Dumper \@count_array;
## print Dumper \%elem_array;
my %thing;
my $f;
my $h;

#my %h = map {
#    $thing = %{ @a[2] }[ 0 .. $#{ @a[0] } ];
# print $#{ @a[2] };
# push @all_refs, advance_arr_ref($arr_ref) foreach 0 .. $max;
my $var = 3;
# print !!$var;

my $buga = BugaBuga->new();

my $crs = {
    '1' => sub { $buga->hi(@_) },
#    '2' => \{  &$buga->hi()  },

};

#    my %hash = (frogs => sub {print "Frogs\n"});
#
#    &{ $hash{frogs} }();

#     my %hash = (frogs => sub {print "Frogs\n"});
#     $hash{frogs}->();

# &{$crs{'1'}->()};
my $coderef = $crs->{'1'};
my $self = {};
bless $self, href::test;

$crs->{'1'}('3');
$self->$coderef('4');

my ( $f, $g );

$f = $g = 1 ? 4  : 5;

print "\nf: $f g: $g\n";

print !!('.') . "\n";

my $f;
my $g;

( $f //= \$g ) ? $g = 1  : $g = 0;

print $$f . "\n";
print $g . "\n";

sub hi {
    my $say = shift;
    print "\n$say\n";
}
sub advance_arr_ref {
    my $arr_ref = shift;
    # print Dumper $arr_ref;
    $arr_ref = \@$arr_ref[ 1 .. $#$arr_ref ];
    # print Dumper $arr_ref;
    return $arr_ref;
}
