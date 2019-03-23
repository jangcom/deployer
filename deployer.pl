#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use autodie        qw(open close);
use Cwd            qw(getcwd);
use feature        qw(say);
use File::Basename qw(basename);
use File::Copy     qw(copy);
use File::Path     qw(make_path);
BEGIN { # Runs at compile time
    chomp(my $onedrive_path = `echo %OneDrive%`);
    unless (exists $ENV{PERL5LIB} and -e $ENV{PERL5LIB}) {
        my %lib_paths = (
            cwd      => ".", # @INC's become dotless since v5.26000
            onedrive => "$onedrive_path/cs/langs/perl",
        );
        unshift @INC, "$lib_paths{$_}/lib" for keys %lib_paths;
    }
}
use My::Toolset qw(:coding :rm);


our $VERSION = '1.01';
our $LAST    = '2019-03-24';
our $FIRST   = '2017-05-15';


sub parse_argv {
    # """@ARGV parser"""
    
    my(
        $argv_aref,
        $cmd_opts_href,
        $run_opts_href,
    ) = @_;
    my %cmd_opts = %$cmd_opts_href; # For regexes
    
    foreach (@$argv_aref) {
        if (/$cmd_opts{deploy_path}/) {
            s/$cmd_opts{deploy_path}//i;
            $run_opts_href->{deploy_path} = $_;
            next;
        }
        
        # Deploy all files in the CWD.
        if (/$cmd_opts{deploy_all}/) {
            push @{$run_opts_href->{deploy_fnames}}, glob '*';
            next;
        }
        
        # The front matter won't be displayed at the beginning of the program.
        if (/$cmd_opts{nofm}/) {
            $run_opts_href->{is_nofm} = 1;
            next;
        }
        
        # The shell won't be paused at the end of the program.
        if (/$cmd_opts{nopause}/) {
            $run_opts_href->{is_nopause} = 1;
            next;
        }
        
        # Files to be deployed
        push @{$run_opts_href->{deploy_fnames}}, $_;
    }
    rm_duplicates($run_opts_href->{deploy_fnames});
    
    return;
}


sub deployer {
    # """Deploy the designated files."""
    
    my $run_opts_href = shift;
    my %fnames_old_new;
    my $lengthiest = 0; # For constructing a conversion
    
    if (not $run_opts_href->{deploy_path}) {
        say "No path designated for file deployment.";
        return;
    }
    
    foreach my $pair (@{$run_opts_href->{deploy_fnames}}) {
        my @splitted = split /=/, $pair;
        if (not -d $splitted[0] and -e $splitted[0]) {
            my $old = $splitted[0];
            my $new = $splitted[1] // $splitted[0];
            $fnames_old_new{$old} = sprintf(
                "%s%s",
                $run_opts_href->{deploy_path} =~ /[\\\/]$/ ? '' : '/',
                # For a to-be-deployed fname specified with its path;
                # e.g. ./subdir/some_file.dat
                $new =~ /[\\\/]/ ? (split /[\\\/]/, $new)[-1] : $new,
            );
            $lengthiest = $splitted[0]
                if length($splitted[0]) > length($lengthiest);
        }
    }
    
    # Deploy the designated files.
    if (%fnames_old_new) {
        # Ask whether to make_path().
        if (not -d $run_opts_href->{deploy_path}) {
            printf(
                "Directory [%s] does not exist. Create? (y/n)>",
                $run_opts_href->{deploy_path},
            );
            while (chomp(my $yn = <STDIN>)) {
                last   if $yn =~ /\by\b/i;
                return if $yn =~ /\bn\b/i;
            }
            make_path($run_opts_href->{deploy_path});
        }
        
        # Perform file deployment.
        say '-' x 70;
        my $conv = '%-'.length($lengthiest).'s';
        while (my($k, $v) = each %fnames_old_new) {
            printf("$conv => %s\n", $k, $run_opts_href->{deploy_path}.$v);
            copy($k, $run_opts_href->{deploy_path}.$v);
        }
        say '-' x 70;
    }
    print %fnames_old_new ?
        "Deployment completed. " :
        "None of the designated files found in the current working dir.\n";
    
    return;
}


sub outer_deployer {
    if (@ARGV) {
        my %prog_info = (
            titl       => basename($0, '.pl'),
            expl       => 'File deployment assistant',
            vers       => $VERSION,
            date_last  => $LAST,
            date_first => $FIRST,
            auth       => {
                name => 'Jaewoong Jang',
                posi => 'PhD student',
                affi => 'University of Tokyo',
                mail => 'jan9@korea.ac.kr',
            },
        );
        my %cmd_opts = ( # Command-line opts
            deploy_path => qr/-?-(?:deploy_)?path=/i,
            deploy_all  => qr/-?-a(ll)?/i,
            nofm        => qr/-?-nofm/i,
            nopause     => qr/-?-nopause/i,
        );
        my %run_opts = ( # Program run opts
            deploy_path   => '',
            deploy_fnames => [],
            is_nofm       => 0,
            is_nopause    => 0,
        );
        
        # ARGV validation and parsing
        validate_argv(\@ARGV, \%cmd_opts);
        parse_argv(\@ARGV, \%cmd_opts, \%run_opts);
        
        # Notification - beginning
        show_front_matter(\%prog_info, 'prog', 'auth', 'no_trailing_blkline')
            unless $run_opts{is_nofm};
        
        # Main
        deployer(\%run_opts);
        
        # Notification - end
        pause_shell() unless $run_opts{is_nopause};
    }
    
    system("perldoc \"$0\"") if not @ARGV;
    
    return;
}


outer_deployer();
__END__


=head1 NAME

deployer - File deployment assistant

=head1 SYNOPSIS

    perl deployer.pl [-deploy_path=path]
                     [-all] [old_file=new_file ...]
                     [-nofm] [-nopause]

=head1 DESCRIPTION

Copy-paste files to a designated path.

=head1 OPTIONS

    -deploy_path=path (short from: -path)
        The path to which designated files will be deployed.

    -all (short form: -a)
        All files in the current working directory will be deployed.

    old_file=new_file ...
        A pair of a filename and its to-be-deployed filename.
        old_file will be used as new_file if new_file is omitted.
        Multiple pairs should be delimited by the space character.
        Accordingly, no space characters are allowed around the equals sign (=).

    -nofm
        The front matter will not be displayed at the beginning of the program.

    -nopause
        The shell will not be paused at the end of the program.
        Use it for a batch run.

=head1 EXAMPLES

    perl deployer.pl -path=../to_boss/ whatnot.pptx=report.pptx
    perl deployer.pl -path=./shibas/ mame_shiba.png
    perl deployer.pl -path=./inus/ -a

=head1 REQUIREMENTS

Perl 5

=head1 AUTHOR

Jaewoong Jang <jan9@korea.ac.kr>

=head1 COPYRIGHT

Copyright (c) 2017-2019 Jaewoong Jang

=head1 LICENSE

This software is available under the MIT license;
the license information is found in 'LICENSE'.

=cut
