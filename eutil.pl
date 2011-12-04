#!/usr/bin/env perl
# ===========================================================================
#
#                            PUBLIC DOMAIN NOTICE
#               National Center for Biotechnology Information
#
#  This software/database is a "United States Government Work" under the
#  terms of the United States Copyright Act.  It was written as part of
#  the author's official duties as a United States Government employee and
#  thus cannot be copyrighted.  This software/database is freely available
#  to the public for use. The National Library of Medicine and the U.S.
#  Government have not placed any restriction on its use or reproduction.
#
#  Although all reasonable efforts have been taken to ensure the accuracy
#  and reliability of the software and data, the NLM and the U.S.
#  Government do not and cannot warrant the performance or results that
#  may be obtained by using this software or data. The NLM and the U.S.
#  Government disclaim all warranties, express or implied, including
#  warranties of performance, merchantability or fitness for any particular
#  purpose.
#
#  Please cite the author in any work or product based on this material.
#
# ===========================================================================
#
# Author:  Oleg Khovayko
#
# File Description: eSearch/eFetch calling example
#  
# ---------------------------------------------------------------------------

use strict;
use warnings;
use LWP::Simple;
use Data::Dumper;
use Getopt::Std;
use File::Basename;

my %defaults = ( 
   'author|a=s'  , 'Default value of Full Author name of search for',
   'journal|j=s' , 'Default value of Journal name of search for',
   'min=s'       , 'Default value of Min year of search from',
   'max=s'       , 'Default value of Max year of search from',
   'query|q=s'   , 'Default value of keyword of search for',
   'limit|l=i'   , 'Search limit count. Default is 500',
   'pdf!'        , 'Retrieve pdf info',
   'tab!'        , 'Print tab separated values format',
   'help|h'      , 'Print help message',
);

my $opts = get_options(\%defaults);

if($opts->{help}) {
	usage();
	exit;
}

$opts->{author}  = '' unless $opts->{author};
$opts->{journal} = '' unless $opts->{journal};
$opts->{query}   = '' unless $opts->{query};

$opts->{limit}   = 500 unless $opts->{limit};

$opts->{min}     = '1999' unless $opts->{min};
$opts->{max}     = (localtime(time))[5] + 1900 unless $opts->{max};

sub get_options {
    my ($defaults, $opts) = (@_);
    my %new_opts;

    use Getopt::Long qw(:config no_ignore_case pass_through);

    GetOptions(\%new_opts, keys %$defaults)
    or die "Can't parse options";

    if (not defined $opts) {
        return \%new_opts;
    }

    foreach my $option (keys %new_opts) {
        $opts->{$option} = $new_opts{$option};
    }

    return $opts;
}

sub usage {
	my $m = basename($0);
	print STDERR <<HELP
Usage
	$m [-author <full author name>] [-journal <journal name>] [-min <min year>] [-max <max year>] [-query <keyword>] [-tab] [-help]

Examples
	$m -author 'Won Cheol Yim'
	$m -q rice

HELP
#	-author
#	-journal
#	-min
#	-max
#	-query
#	-help
}

# ---------------------------------------------------------------------------
# Subroutine to prompt user for variables in the next section

sub ask_user {
  print STDERR "$_[0] [$_[1]]: ";
  my $rc = <>;
  chomp $rc;
  if($rc eq "") { $rc = $_[1]; }
  return $rc;
}

# ---------------------------------------------------------------------------
# Subroutine to parse medline format

sub parse_medline {
	my ($raw) = @_;
	my %records;

	my @raw = split /[\r\n]/, $raw;

	my $cur_pmid;
	my $cur_key;
	my %medline;
	foreach my $aLine (@raw) {
		my $value;
		if($aLine =~ m{^([A-Z]{2,4}) *- (.+)$}) {
			$cur_key = $1;
			$value = $2;
		}
		else {
			$value = $aLine;
			$value =~ s/^\s+//;
			$value =~ s/\s+$//;
		}

		next if !defined $value or $value eq '';

		if($cur_key eq 'PMID') {
			$cur_pmid = $value;
			$records{$cur_pmid}->{PMID} = $value;
		}
		else {
			push @{ $records{$cur_pmid}->{$cur_key} }, $value;
		}
	}

	return %records;
}

# ---------------------------------------------------------------------------
# Define library for the 'get' function used in the next section.
# $utils contains route for the utilities.
# $db, $query, and $report may be supplied by the user when prompted; 
# if not answered, default values, will be assigned as shown below.

my $utils = "http://www.ncbi.nlm.nih.gov/entrez/eutils";

my $db     = "Pubmed";
my $report = "medline";
my $author  = ask_user("Author",       $opts->{author});
my $journal = ask_user("journal_name", $opts->{journal});
my $query   = ask_user("query",        $opts->{query});
my $mindate = ask_user("mindate",      $opts->{min});
my $maxdate = ask_user("maxdate",      $opts->{max});

# ---------------------------------------------------------------------------
# $esearch cont햕ns the PATH & parameters for the ESearch call
# $esearch_result containts the result of the ESearch call
# the results are displayed 햚d parsed into variables 
# $Count, $QueryKey, and $WebEnv for later use and then displayed.

my $esearch = "$utils/esearch.fcgi?" .
              "db=$db&retmax=1&usehistory=y&mindate=$mindate&maxdate=$maxdate&datetype=pdat&term=";
	
	$author .="[FAU]" if $author ne '';
	
	$journal .="[TA]" if $journal ne '';

my $esearch_result = get($esearch . $author . $journal . $query);

#print STDERR "\nESEARCH RESULT: $esearch_result\n";

$esearch_result =~ 
  m|<Count>(\d+)</Count>.*<QueryKey>(\d+)</QueryKey>.*<WebEnv>(\S+)</WebEnv>|s;

my $Count    = $1;
my $QueryKey = $2;
my $WebEnv   = $3;

print STDERR "Count = $Count; QueryKey = $QueryKey; WebEnv = $WebEnv\n";

if($Count > $opts->{limit}) {
	print STDERR "Result count is over $opts->{limit}, limitting $opts->{limit}\n";
	$Count = $opts->{limit};
}

# ---------------------------------------------------------------------------
# this area defines a loop which will display $retmax citation results from 
# Efetch each time the the Enter Key is pressed, after a prompt.

my $retstart;
my $retmax=20;
my %medlines;

for($retstart = 0; $retstart < $Count; $retstart += $retmax) {
    my $efetch = "$utils/efetch.fcgi?" .
        "rettype=$report&retmode=medline&retstart=$retstart&retmax=$retmax&" .
        "db=$db&query_key=$QueryKey&WebEnv=$WebEnv";
    my %record;

    print STDERR "\nEF_QUERY=$efetch\n";     

    my $efetch_result = get($efetch);

    $efetch_result =~ m|<pre>(.+)</pre>|s;
    $efetch_result = $1;

	my %medlines_part;
	%medlines_part = parse_medline($efetch_result);

	foreach my $key (keys %medlines_part) {
		$medlines{ $key } = $medlines_part{$key};
	}
	
#    my $pmid = $record{PMID};
#    my $dp   = $record{DP};
#    my $ti   = $record{TI};
#    my $ab   = $record{AB};
#    my $is   = join ";", @{$record{IS}};
#    my $au   = join ";", @{$record{AU}};

    
    #print join "\t", $pmid, $dp, $ti, $ab, $is, $au;
    #print "\n";
}

#print Dumper(\%medlines);

if($opts->{pdf}) {
	foreach my $pmid (keys %medlines) {
		my $medline = $medlines{$pmid};
		printf "[%s] %s\n", $pmid, join('', @{$medline->{TI}});
		my $url_pdf_fetch = sprintf 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&id=%s&retmode=ref&cmd=prlinks&tool=pdfetch', $pmid;
		print $url_pdf_fetch, "\n";
		#my $pdf = get($url_pdf_fetch);
		#print STDERR $pdf;
	}
}
elsif($opts->{tab}) {
	foreach my $pmid (keys %medlines) {
		my $medline = $medlines{$pmid};
		#printf "[%s] %s\n", $pmid, join('', @{$medline->{TI}});
		print join "\t",
			$pmid,
			join(' ', @{ $medline->{TI} }),
			join(';', @{ $medline->{AU} }),
			join('',  @{ $medline->{DP} }),
			join(' ', @{ $medline->{TA} }),
			join(' ', @{ $medline->{AB} });
		print "\n";
	}
}
else {
	foreach my $pmid (keys %medlines) {
		my $medline = $medlines{$pmid};
		printf "[%s] %s\n", $pmid, join('', @{$medline->{TI}});
	}
}
