package Koha::Plugin::Com::ByWaterSolutions::AuthCheck;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Branch;
use C4::Members;
use C4::Auth;
use C4::Search;
use MARC::Record;

## Here we set our plugin version
our $VERSION = 1.00;

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name   => 'Unused Authority Report',
    author => 'Nick Clemens',
    description => 'This plugin searches your system for authorities that have no attached records',
    date_authored   => '2016-02-25',
    date_updated    => '2016-02-25',
    minimum_version => '3.18',
    maximum_version => undef,
    version         => $VERSION,
};

## This is the minimum code required for a plugin's 'new' method
##iMore can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}


## The existance of a 'report' subroutine means the plugin is capable
## of running a report. This example report can output a list of patrons
## either as HTML or as a CSV file. Technically, you could put all your code
## in the report method, but that would be a really poor way to write code
## for all but the simplest reports
sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('output') ) {
        $self->report_step1();
    }
    else {
       $self->report_step2();
    }
}


## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;

    my $table = $self->get_qualified_table_name('mytable');

    return C4::Context->dbh->do( "
        CREATE TABLE  $table (
            `borrowernumber` INT( 11 ) NOT NULL
        ) ENGINE = INNODB;
    " );
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;

    my $table = $self->get_qualified_table_name('mytable');

    return C4::Context->dbh->do("DROP TABLE $table");
}

## These are helper functions that are specific to this plugin
## You can manage the control flow of your plugin any
## way you wish, but I find this is a good approach
sub report_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'report-step1.tt' });

    print $cgi->header();
    print $template->output();
}

sub report_step2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $dbh = C4::Context->dbh;

    my $output = $cgi->param('output');
    my $lower_lim = $cgi->param('lower_lim');
    my $upper_lim = $cgi->param('upper_lim');

    my $query = "SELECT authid,authtypecode,IF( authtypecode='CORPO_NAME',ExtractValue(marcxml,'//datafield[\@tag=\"110\"]/*'),
                               IF( authtypecode='GENRE/FORM',ExtractValue(marcxml,'//datafield[\@tag=\"155\"]/*'),
                               IF( authtypecode='GEOGR_NAME',ExtractValue(marcxml,'//datafield[\@tag=\"151\"]/*'),
                               IF( authtypecode='MEETI_NAME',ExtractValue(marcxml,'//datafield[\@tag=\"111\"]/*'),
                               IF( authtypecode='PERSO_NAME',ExtractValue(marcxml,'//datafield[\@tag=\"100\"]/*'),
                               IF( authtypecode='TOPIC_TERM',ExtractValue(marcxml,'//datafield[\@tag=\"150\"]/*'),
                               IF( authtypecode='UNIF_TITLE',ExtractValue(marcxml,'//datafield[\@tag=\"130\"]/*'),''))))))) AS main_term
        FROM auth_header";
    if ( $lower_lim*$upper_lim ) { $query .= " WHERE authid BETWEEN $lower_lim AND $upper_lim "; }
    elsif ($lower_lim) {$query .= " WHERE authid > $lower_lim ";}
    elsif ($upper_lim) {$query .= " WHERE authid < $upper_lim ";}
    $query .= " ORDER BY authid";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my $i=0;
    my @results;
    my $i =0 ;
    while ( my $row = $sth->fetchrow_hashref() ) {
        $i++;
        if($i>5_000){last;}
        my $a_query = 'an='.$row->{'authid'};
        my ($err,$res,$used) = C4::Search::SimpleSearch($a_query,0,10);
        if (defined $err) { $used=0; }
        if ($used > 0){ next}
        else{push( @results, $row );}
    }


    my $filename;
    if ( $output eq "csv" ) {
        print $cgi->header( -attachment => 'unusedauthorities.csv' );
        $filename = 'report-step2-csv.tt';
    }
    else {
        print $cgi->header();
        $filename = 'report-step2-html.tt';
    }

    my $template = $self->get_template({ file => $filename });

    $template->param(
        results_loop => \@results,
    );

    print $template->output();
}

1;
