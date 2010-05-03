#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", 'lib', 'extlib';
use File::Spec;

my @tests;
my $imagedir = File::Spec->catdir($Bin, 'images' );

BEGIN {
    @tests = (
        {
            label   => 'No parameters',
            params  => {},
            results => [
                "gabba.gif",
                "stella.jpg"
            ]
        },
        {
            label   => 'Exclude jpg',
            params  => { excludeext => 'jpg' },
            results => [
                "gabba.gif"
            ]
        },
        {
            label   => 'Include jpg',
            params  => { includeext => 'jpg' },
            results => [
                "stella.jpg"
            ]
        },
        {
            label   => 'Recursive',
            params  => { recurse => 1 },
            results => [
                "cute/alexis.jpg",
                "cute/basking.jpg",
                "cute/devious.jpg",
                "cute/puppies/first-picture.jpg",
                "cute/puppies/tongue-stuck.jpg",
                "cute/puppies/will-cute-for-tips.JPG",
                "gabba.gif",
                "net/internet-high-five.JPG",
                "net/melody-flower.png",
                "stella.jpg"
            ]
        },
        {
            label   => 'Recursive, exclude jpg',
            params  => { recurse => 1, excludeext => 'jpg' },
            results => [
                "gabba.gif",
                "net/melody-flower.png",
            ]
        },
        {
            label   => 'Recursive, include jpg',
            params  => { recurse => 1, includeext => 'jpg' },
            results => [
                "cute/alexis.jpg",
                "cute/basking.jpg",
                "cute/devious.jpg",
                "cute/puppies/first-picture.jpg",
                "cute/puppies/tongue-stuck.jpg",
                "cute/puppies/will-cute-for-tips.JPG",
                "net/internet-high-five.JPG",
                "stella.jpg"
            ]
        },
    );
}
use Test::More tests => scalar @tests;

use AssetHandler::Util;
my $meth     = AssetHandler::Util->can('files_from_directory');

foreach my $test ( @tests ) {
    my @results
        = map { File::Spec->catfile( $imagedir, $_) } 
            @{$test->{results}};
    is_deeply( [ $meth->( $imagedir, $test->{params} ) ], \@results, $test->{label} );
}
