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
use Carp           qw(croak);
use constant ARRAY  => ref [];
use constant HASH   => ref {};


our $VERSION = '1.03';
our $LAST    = '2019-10-26';
our $FIRST   = '2017-05-15';


#----------------------------------My::Toolset----------------------------------
sub show_front_matter {
    # """Display the front matter."""

    my $prog_info_href = shift;
    my $sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg of [$sub_name] must be a hash ref!"
        unless ref $prog_info_href eq HASH;

    # Subroutine optional arguments
    my(
        $is_prog,
        $is_auth,
        $is_usage,
        $is_timestamp,
        $is_no_trailing_blkline,
        $is_no_newline,
        $is_copy,
    );
    my $lead_symb = '';
    foreach (@_) {
        $is_prog                = 1  if /prog/i;
        $is_auth                = 1  if /auth/i;
        $is_usage               = 1  if /usage/i;
        $is_timestamp           = 1  if /timestamp/i;
        $is_no_trailing_blkline = 1  if /no_trailing_blkline/i;
        $is_no_newline          = 1  if /no_newline/i;
        $is_copy                = 1  if /copy/i;
        # A single non-alphanumeric character
        $lead_symb              = $_ if /^[^a-zA-Z0-9]$/;
    }
    my $newline = $is_no_newline ? "" : "\n";

    #
    # Fill in the front matter array.
    #
    my @fm;
    my $k = 0;
    my $border_len = $lead_symb ? 69 : 70;
    my %borders = (
        '+' => $lead_symb.('+' x $border_len).$newline,
        '*' => $lead_symb.('*' x $border_len).$newline,
    );

    # Top rule
    if ($is_prog or $is_auth) {
        $fm[$k++] = $borders{'+'};
    }

    # Program info, except the usage
    if ($is_prog) {
        $fm[$k++] = sprintf(
            "%s%s - %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $prog_info_href->{titl},
            $prog_info_href->{expl},
            $newline,
        );
        $fm[$k++] = sprintf(
            "%s%s v%s (%s)%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $prog_info_href->{titl},
            $prog_info_href->{vers},
            $prog_info_href->{date_last},
            $newline,
        );
        $fm[$k++] = sprintf(
            "%sPerl %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $^V,
            $newline,
        );
    }

    # Timestamp
    if ($is_timestamp) {
        my %datetimes = construct_timestamps('-');
        $fm[$k++] = sprintf(
            "%sCurrent time: %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $datetimes{ymdhms},
            $newline,
        );
    }

    # Author info
    if ($is_auth) {
        $fm[$k++] = $lead_symb.$newline if $is_prog;
        $fm[$k++] = sprintf(
            "%s%s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $prog_info_href->{auth}{$_},
            $newline,
        ) for (
            'name',
#            'posi',
#            'affi',
            'mail',
        );
    }

    # Bottom rule
    if ($is_prog or $is_auth) {
        $fm[$k++] = $borders{'+'};
    }

    # Program usage: Leading symbols are not used.
    if ($is_usage) {
        $fm[$k++] = $newline if $is_prog or $is_auth;
        $fm[$k++] = $prog_info_href->{usage};
    }

    # Feed a blank line at the end of the front matter.
    if (not $is_no_trailing_blkline) {
        $fm[$k++] = $newline;
    }

    #
    # Print the front matter.
    #
    if ($is_copy) {
        return @fm;
    }
    else {
        print for @fm;
        return;
    }
}


sub validate_argv {
    # """Validate @ARGV against %cmd_opts."""

    my $argv_aref     = shift;
    my $cmd_opts_href = shift;
    my $sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg of [$sub_name] must be an array ref!"
        unless ref $argv_aref eq ARRAY;
    croak "The 2nd arg of [$sub_name] must be a hash ref!"
        unless ref $cmd_opts_href eq HASH;

    # For yn prompts
    my $the_prog = (caller(0))[1];
    my $yn;
    my $yn_msg = "    | Want to see the usage of $the_prog? [y/n]> ";

    #
    # Terminate the program if the number of required arguments passed
    # is not sufficient.
    #
    my $argv_req_num = shift; # (OPTIONAL) Number of required args
    if (defined $argv_req_num) {
        my $argv_req_num_passed = grep $_ !~ /-/, @$argv_aref;
        if ($argv_req_num_passed < $argv_req_num) {
            printf(
                "\n    | You have input %s nondash args,".
                " but we need %s nondash args.\n",
                $argv_req_num_passed,
                $argv_req_num,
            );
            print $yn_msg;
            while ($yn = <STDIN>) {
                system "perldoc $the_prog" if $yn =~ /\by\b/i;
                exit if $yn =~ /\b[yn]\b/i;
                print $yn_msg;
            }
        }
    }

    #
    # Count the number of correctly passed command-line options.
    #

    # Non-fnames
    my $num_corr_cmd_opts = 0;
    foreach my $arg (@$argv_aref) {
        foreach my $v (values %$cmd_opts_href) {
            if ($arg =~ /$v/i) {
                $num_corr_cmd_opts++;
                next;
            }
        }
    }

    # Fname-likes
    my $num_corr_fnames = 0;
    $num_corr_fnames = grep $_ !~ /^-/, @$argv_aref;
    $num_corr_cmd_opts += $num_corr_fnames;

    # Warn if "no" correct command-line options have been passed.
    if (not $num_corr_cmd_opts) {
        print "\n    | None of the command-line options was correct.\n";
        print $yn_msg;
        while ($yn = <STDIN>) {
            system "perldoc $the_prog" if $yn =~ /\by\b/i;
            exit if $yn =~ /\b[yn]\b/i;
            print $yn_msg;
        }
    }

    return;
}


sub pause_shell {
    # """Pause the shell."""

    my $notif = $_[0] ? $_[0] : "Press enter to exit...";

    print $notif;
    while (<STDIN>) { last; }

    return;
}


sub rm_duplicates {
    # """Remove duplicate items from an array."""

    my $aref = shift;
    my $sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg of [$sub_name] must be an array ref!"
        unless ref $aref eq ARRAY;

    my(%seen, @uniqued);
    @uniqued = grep !$seen{$_}++, @$aref;
    @$aref = @uniqued;

    return;
}
#-------------------------------------------------------------------------------


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


sub deployer_runner {
    # """deployer running routine"""

    if (@ARGV) {
        my %prog_info = (
            titl       => basename($0, '.pl'),
            expl       => 'File deployment assistant',
            vers       => $VERSION,
            date_last  => $LAST,
            date_first => $FIRST,
            auth       => {
                name => 'Jaewoong Jang',
#                posi => '',
#                affi => '',
                mail => 'jangj@korea.ac.kr',
            },
        );
        my %cmd_opts = ( # Command-line opts
            deploy_path => qr/-?-(?:deploy_)?path=/i,
            deploy_all  => qr/-?-a(ll)?\b/i,
            nofm        => qr/-?-nofm\b/i,
            nopause     => qr/-?-nopause\b/i,
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
        $run_opts{is_nopause} ? print "\n" : pause_shell();
    }

    system("perldoc \"$0\"") if not @ARGV;

    return;
}


deployer_runner();
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

=head1 SEE ALSO

L<deployer on GitHub|https://github.com/jangcom/deployer>

=head1 AUTHOR

Jaewoong Jang <jangj@korea.ac.kr>

=head1 COPYRIGHT

Copyright (c) 2017-2019 Jaewoong Jang

=head1 LICENSE

This software is available under the MIT license;
the license information is found in 'LICENSE'.

=cut
