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
my $out_filename;
my $thisline;
my $accession;
my $tmp_asn1file;
my $fix_asn1_file;
my $se2bss_asn1_file;
my $username;
my $idstat_file;
my $pwd;
my @linelist;
my ($retval) = 0;

$acc_file = shift || die "You must specify an input filename! The input file should contain a list accessions to be loaded, one accession per line\n";
$out_filename = shift || die "You must specify a input filename and output file name!\n";

open (INFILE, $acc_file) || die "Unable to open $acc_file!\n";
#open (OUTFILE, ">$out_filename") || die "Unable to open $out_filename!\n";
open (FIXASN_FILE, ">$out_filename") || die "Unable to open $out_filename!\n";

print "\nPlease enter your sybase user name: ";
chomp ($username = <STDIN>);

print "\nPlease enter your sybase password: ";
chomp ($pwd = <STDIN>);

$retval = idstat1($acc_file,$idstat_file);
if ($retval != 1) {
    print STDERR "$0 : Error : unexpected return value from idstat1 subroutine : $retval";
    exit(10);
}

&FixAsn1;
&LoadIntermediate;
#&ResetFailFlag;

close ($acc_file);
close (OUTFILE);

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
	unless ($tokens[6] eq 'No' && $tokens[7] eq 'No') {
	    push(@problem_accs,$tokens[0]);
	}
    }
    close(IDSTATFILE);

    if (@problem_accs) {
	print STDOUT "$0 : Error : $sub_name : Some accessions are withdrawn or suppressed:\n";
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
my $line1;
my $line2;
my ($sub_name) = (caller(0))[3];

  system ("seqfetch -G $acc_file -o tmp_asn1file");
  system ("se2bss -i tmp_asn1file -o se2bss_asn1_file");
  #open (OUT, $fix_asn1_file) || die "Unable to open $fix_asn1_file for writing!\n";

  
  if (! open(SE2BSS_FILE, "<se2bss_asn1_file")) {
      print STDERR "$0 : Error : $sub_name : open failed for file se2bss_asn1_file\n";
      return -10;
  }
  if (! open(FIXASN_FILE, ">fix_asn1_file")) {
      print STDERR "$0 : Error : $sub_name : open failed for file fix_asn1_file\n";
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

######################################################################
#Load the intermediate file with striped locus names to id.
#Report any errors found and run idstat to confirm load
######################################################################
sub LoadIntermediate
{


  # Investigate setting up the %ENV hash ?
  # That might work (for subsequent idload.pl call) for a single env variable, like this one:

#  $ENV{"IDLOADSEQENTRY"} = "idloadseqentry -O AllowGiFarPtr,AllowSought,AcceptSeqVer,IgnoreDeadHistory,IgnoreInvalidHist";

  system ("source /am/ncbiapdata/database_env/id_env.csh");

  system ("setenv IDLOADSEQENTRY \"idloadseqentry -O AllowGiFarPtr,AcceptDate,AllowGiFarPtr,AllowSought,AcceptSeqVer,IgnoreDeadHistory,IgnoreInvalidHist\"");

  # Let's see what ID-related variables now exist in the environment
  system ("printenv | grep ID");

  ## system ("idload.pl -a $fix_asn1_file -d `pwd` -l `pwd`/idload -P $pwd -o SWISSPROT");

}

######################################################################
#Repeat idstat to test the intermediate load, querry the user as to whether the
#script should continue or exit. If the intermediate load is successful, 
#proceed with ResetFailFlag
######################################################################
sub idstat2
{
}

######################################################################
#Reset fail flag for accessions in processing queue so the new version can load
######################################################################
sub ResetFailFlag
{
#  system ("setenv LD_LIBRARY_PATH /netopt/Sybase/clients/12.0-EBF9209/lib");
#  system ("ffdbx_mssql -i INFILE -d ftds -m q -S FLATFILE_NEW -s swissprot -T UPDATE -U $username -P $pwd");
}
