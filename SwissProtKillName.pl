#!/usr/bin/perl

######################################################################
#SwissProtLoader.pl
#script to fix SwissProt accessions that will not load due to locus name collisions
#SwissProt likes to swap locus names between accessions but we link the locus name and the
#accession so these frequently fail to load when it's a simple swap. 
#In put file is a list of accessions to be loaded one accession per line.
######################################################################

use strict;

my $acc_file;
my $out_fname_prefix;

my $idstat_file;
my $tmp_asn1_file;
my $fix_asn1_file;
my $se2bss_asn1_file;
my ($retval) = 0;

$out_fname_prefix = shift || die "You must specify a filename prefix for all the output filenames!\n";

if ($out_fname_prefix eq "") {
    die "No filename prefix provided for output files";
}

$acc_file = $out_fname_prefix . ".acc";
unless ( -e $acc_file ) {
    die "File not found : $acc_file";
}

$idstat_file = $out_fname_prefix . ".idstat";
$tmp_asn1_file = $out_fname_prefix . ".cse";
$se2bss_asn1_file = $out_fname_prefix . ".orig";
$fix_asn1_file = $out_fname_prefix . ".fixed";

$retval = idstat1($acc_file,$idstat_file);
if ($retval != 1) {
    print STDERR "$0 : Error : unexpected return value from idstat1 subroutine : $retval";
    exit(10);
}

$retval = FixAsn1($acc_file,$tmp_asn1_file,$se2bss_asn1_file,$fix_asn1_file);
if ($retval != 1) {
    print STDERR "$0 : Error : unexpected return value from FixAsn1 subroutine : $retval";
    exit(20);
}

exit(0);

######################################################################
#idstat to check for withdrawn or suppressed accessions before we do anything
#NOTE all suppressed and withdrawn sequences need to be unsuppressed or unwithdrawn
#before the script will work correctly. Subroutine will output a list of withdrawn
#or suppressed accessions. If all accessions are live, it will proceed with the
#next subroutine with no output or message. 
######################################################################


sub idstat1
{
    my ($acc_file,$idstat_file) = @_;
    my ($sub_name) = (caller(0))[3];
    my @tokens;
    my @problem_accs;

    if (!$idstat_file) {
      $idstat_file = "idstat_file";
    }

    if ($acc_file eq "") {
	print STDERR "$0 : Error : $sub_name : accession or idstat output file arguments are empty\n";
	return 0;
    }

    system ("idstat -A $acc_file -mr -nh -r F > $idstat_file");
    if ($? != 0) {
	print STDERR "$0 : Error : $sub_name : system call for idstat failed\n";
	return -1;
    }
    if (! open(IDSTATFILE, "<$idstat_file")) {
	print STDERR "$0 : Error : $sub_name : open failed for file $idstat_file\n";
	return -2;
    }
    while(<IDSTATFILE>) {
	@tokens = split(/\s+/);
	unless (/Alive/i) {
	    push(@problem_accs,$tokens[0]);
	}
	unless ($tokens[6] eq 'No' && $tokens[7] eq 'No') {
	    push(@problem_accs,$tokens[0]);
	}
    }
    close(IDSTATFILE);

    if (@problem_accs) {
	print STDOUT "$0 : Error : $sub_name : Some accessions are withdrawn or suppressed or dead:\n";
	foreach (@problem_accs) {
	    print STDOUT "$_ ";
	}
	print STDOUT "\n";
	return -3;
    }
    return 1;
}

######################################################################
#Download current asn.1 and create bio-seq set
#Remove the offending locus name from the asn.1
#save intermediate asn.1 to a temp file
######################################################################
sub FixAsn1
{
    my ($acc_file,$tmp_asn1_file,$se2bss_asn1_file,$fix_asn1_file) = @_;
    my $line1;
    my $line2;
    my ($sub_name) = (caller(0))[3];

    system ("seqfetch -G $acc_file -o $tmp_asn1_file");
    system ("se2bss -i $tmp_asn1_file -o $se2bss_asn1_file");
    
    if (! open(SE2BSS_FILE, "<$se2bss_asn1_file")) {
	print STDERR "$0 : Error : $sub_name : open failed for file $se2bss_asn1_file\n";
	return -10;
    }
    if (! open(FIXASN_FILE, ">$fix_asn1_file")) {
	print STDERR "$0 : Error : $sub_name : open failed for file $fix_asn1_file\n";
	return -11;
    }
    while(<SE2BSS_FILE>) {
	chomp;
	$line1 = $_;

	if ($line1 =~ /^\s+swissprot \{$/) {
	    print FIXASN_FILE "$line1\n";

	    $line2 = <SE2BSS_FILE>;
	    chomp($line2);

	    if ($line2 =~ /^\s+name \"\w+\" ,$/) {
		# No-op : Don't print the SP name identifier
	    }
	    else {
		print FIXASN_FILE "$line2\n";
	    }
	}
	else {
	    print FIXASN_FILE "$line1\n";
	}
    }
    close(SE2BSS_FILE);
    close(FIXASN_FILE);
}
