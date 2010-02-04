#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", 'lib', 'extlib';

use Test::More tests => 3;

use_ok('AssetHandler::App::CMS');
use_ok('AssetHandler::Tool::Import');
use_ok('AssetHandler::Util');
