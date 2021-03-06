#!/usr/bin/perl

my $VERSION="1.0";
my $AUTHOR="Ksenia Krasileva";
my $EMAIL="krasileva [at] ucdavis.edu";

use strict;
use Getopt::Long;
use Data::Dumper;
use Bio::SeqIO;

my ($input, $output, $fasta);

my $usage=usage();

GetOptions(
	'input|i:s' => \$input,
	'output|o:s' => \$output,
	'fasta|f:s'  => \$fasta,
#	'help',
) or die $usage;

die "ERROR: No input file specified\n$usage" unless defined($input);
die "ERROR: No output file specified\n$usage" unless defined($output);
die "ERROR: No fasta file specified\n$usage" unless defined($fasta);

# findorf format
# IWGSC_CSS_1AL_scaff_3892569	findorf	predicted_orf	5621	6310	.	1	1	diff_5prime_most_start_and_orf 279;contig_len 11121;distant_start None;num_5prime_ATG 47;num_orf_candidates 81;orf_type full_length;internal_stop True;majority_frameshift False;most_5prime_query_start 5713;most_5prime_relative gl;no_prediction_reason None;most_5prime_sbjct_start 30;pfam_extended_5prime None;num_relatives 1

my $data;
my %data;
my $n=0;
my $t=0;
my $seqname='';
my $prev_seqname='';

open FILE1, "<", $input or die "ERROR: Cannot open input file $input\n$usage";

while (my $line=<FILE1>){

	chomp $line;
	my @findorf = split ("\t", $line);
	$seqname=$findorf[0];
	
	#reset if new contig
	if ($prev_seqname ne $seqname){
		$n=0;
	}
	
	$n++;
	$t++;
	
	$data->{$seqname}->{$n}->{'source'} = $findorf[1];
	$data->{$seqname}->{$n}->{'start'} = $findorf[3];
	$data->{$seqname}->{$n}->{'stop'} = $findorf[4];
	$data->{$seqname}->{$n}->{'strand'} = get_sign($findorf[6]);
	$data->{$seqname}->{$n}->{'frame'} = $findorf[7];
	$data->{$seqname}->{$n}->{'gene_id'} = 'Gluten_gene_' . $t;
	$data->{$seqname}->{$n}->{'transcript_id'} = 'Gluten_gene_' . $t . ".1";
	$data->{$seqname}->{$n}->{'protein_id'} = 'Gluten_gene_' . $t . ".1";

	$prev_seqname=$seqname;
	
}

close FILE1;

# load fasta as SeqIO object

my $inseq = Bio::SeqIO->new(
                             -file   => $fasta,
                             -format => 'Fasta',
                             );

# ensembl GTF format
# it needs to be sorted in the same order as chromosomes in the fasta file.
# IWGSC_CSS_6DL_scaff_127793	protein_coding	exon	526	645	.	+	.	 gene_id "Traes_6DL_7FFFE462C"; transcript_id "Traes_6DL_7FFFE462C.2"; exon_number "1"; seqedit "false";
# IWGSC_CSS_6DL_scaff_127793	protein_coding	CDS	574	645	.	+	0	 gene_id "Traes_6DL_7FFFE462C"; transcript_id "Traes_6DL_7FFFE462C.2"; exon_number "1"; protein_id "Traes_6DL_7FFFE462C.2";
                             
open FILEOUT, ">", $output or die "ERROR: Cannot open output file $output\n$usage";
open FILEOUT2, ">", $output . ".fa" or die "ERROR: Cannot open output file $output\n$usage";

while (my $seq  = $inseq->next_seq){

		my ($seqname) = split(" ", $seq->id);

	#check if there are gtf entries for this contig
	
		if ( defined $data->{$seqname} ) {

			foreach my $k (keys % { $data->{$seqname} } ){

			print "Writing definition for a gene $data->{$seqname}->{$k}->{'transcript_id'} found on $seqname", "\n";
			
				my $comments_exon = "gene_id \"$data->{$seqname}->{$k}->{'gene_id'}\"; transcript_id \"$data->{$seqname}->{$k}->{'transcript_id'}\"; exon_number \"1\"; seqedit \"false\";";
 			 	my $comments_CDS = "gene_id \"$data->{$seqname}->{$k}->{'gene_id'}\"; transcript_id \"$data->{$seqname}->{$k}->{'transcript_id'}\"; exon_number \"1\"; protein_id \"$data->{$seqname}->{$k}->{'protein_id'}\";";
  	
				my @outexon = ($seqname, 'protein_coding', 'exon', $data->{$seqname}->{$k}->{'start'}, $data->{$seqname}->{$k}->{'stop'}, '.', $data->{$seqname}->{$k}->{'strand'}, "." , $comments_exon);
				my @outCDS = ($seqname, 'protein_coding', 'CDS', $data->{$seqname}->{$k}->{'start'}, $data->{$seqname}->{$k}->{'stop'}, '.', $data->{$seqname}->{$k}->{'strand'}, $data->{$seqname}->{$k}->{'frame'}, $comments_CDS); 
 
			 	print FILEOUT join ("\t", @outexon), "\n", join ("\t", @outCDS), "\n";
 			}
 			
 			print FILEOUT2  ">", $seq->id, "\n", $seq->seq(), "\n";
 		}

}

close FILEOUT;
close FILEOUT2;

print "All done!\n";

sub usage {
    my $usage =<<END;

findorf2ensembl.pl
version $VERSION

By $AUTHOR ( $EMAIL )

Usage: perl script.pl [options]

Options

-i | --input [file]       GTF file generated by findorf
-o | --output [file]      GTF file to be generated in Ensembl format
-f | --fasta [file]       Reference fasta file (needed to sort Ensembl GTF)

END

    return $usage;
}

sub get_sign{

	my $number = shift;
	my $sign='';
	
	if ( $number > 0){
		 $sign = '+';
	} 
	elsif ( $number < 0){
		 $sign = '-'
	}
	else{
	die "ERROR: Cannot parse the strand (not numeric): $number\n";
	}
	
return $sign;
}

