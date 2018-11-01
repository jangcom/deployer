#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use autodie        qw(open close);
use feature        qw(say);
use File::Basename qw(basename);
use File::Copy     qw(copy);
use File::Path     qw(make_path);
use Carp           qw(croak);
use constant ARRAY => ref [];
use constant HASH  => ref {};


#
# Outermost lexicals
#
my %prog_info = (
    titl        => basename($0, '.pl'),
    expl        => 'Files deployer',
    vers        => 'v1.0.0',
    date_last   => '2018-09-27',
    date_first  => '2017-05-15',
    opts        => { # Command options
        fname_path_sep => '=',
        same_path_flag => '-path=',
    },
    auth        => {
        name => 'Jaewoong Jang',
        posi => 'PhD student',
        affi => 'University of Tokyo',
        mail => 'jang.comsci@gmail.com',
    },
    usage       => <<'    END_HEREDOC'
    NAME
        deployer - File deployer

    SYNOPSIS
        perl deployer.pl [file=path ...|file... -path=same_path] 

    DESCRIPTION
        Copy-paste files into the designated paths.

    OPTIONS
        file=path
            A pair of a file and its to-be-deployed path.
            Multiple pairs are delimited by the space character.
        file... -path=same_path
            Multiple files to be deployed into the same path.
            Filenames are delimited by the space character.

    EXAMPLES
        perl deployer.pl whatnot.pptx=../to_boss
        perl deployer.pl ./mame/mame_shiba.png=./shibas
        perl deployer.pl ./mame/mame_shiba.png ./kuro/kuro_shiba.jpg -path=./shibas

    REQUIREMENTS
        Perl 5

    SEE ALSO
        perl(1)

    AUTHOR
        Jaewoong Jang <jang.comsci@gmail.com>

    COPYRIGHT
        Copyright (c) 2017-2018 Jaewoong Jang

    LICENSE
        This software is available under the MIT license;
        the license information is found in 'LICENSE'.
    END_HEREDOC
);


#
# Subroutine calls
#
if (@ARGV) {
    show_front_matter(\%prog_info, 'prog', 'auth');
    validate_argv(\%prog_info, \@ARGV);
    validate_argv_additional();
    deployer();
}
elsif (not @ARGV) {
    show_front_matter(\%prog_info, 'usage');
}
pause_shell();


#
# Subroutine definitions
#
sub validate_argv_additional { # In addition to My::Toolsets::validate_argv()
    my $argv_stringified;
    $argv_stringified .= $_ for @ARGV;
    
    # Case 1: Filename-path pairs are designated,
    #         while the option for the same path is turned on.
    if (
        $argv_stringified =~ /$prog_info{opts}->{same_path_flag}/i and
        $argv_stringified =~ /
            [^$prog_info{opts}->{same_path_flag}]
            $prog_info{opts}->{fname_path_sep}
        /ix
    ) {
        print $prog_info{usage};
        printf(
            "\n".
            "    | Guess you've turned on the option %s, in which case\n".
            "    | only filenames separated by %s should be passed.\n".
            "    | Please refer to the usage shown above.\n",
            $prog_info{opts}->{same_path_flag},
            $prog_info{opts}->{fname_path_sep}
        );
        exit;
    }
    
    # Case 2: The option for the same path is turned on multiple times.
    if (
        $argv_stringified =~ /
            $prog_info{opts}->{same_path_flag}
            .*
            $prog_info{opts}->{same_path_flag}
        /ix
    ) {
        print $prog_info{usage};
        printf(
            "\n".
            "    | Guess you've turned on the option %s multiple times.\n".
            "    | Please reduce them to one.\n",
            $prog_info{opts}->{same_path_flag}
        );
        exit;
    }
}


sub deployer {
    my @_argv = @ARGV;
    my @fnames;
    my %fnames_from_to;
    my $same_path;
    my $is_same_path = 0;
    my $lengthiest   = 0; # For constructing a conversion
    my $path_delim   = $^O =~ /MSWin/i ? '\\' : '/';
    
    #
    # Determine which copy-paste method to use; see (i) and (ii) below.
    #
    for (@_argv) {
        if (/$prog_info{opts}->{same_path_flag}/i) {
            $is_same_path = 1;
            ($same_path = $_) =~ s/$prog_info{opts}->{same_path_flag}//i;
        }
    }
    
    # (i) Filename-path pairs
    if ($is_same_path == 0) {
        @fnames = @_argv;
        my @_splitted;
        foreach my $glued (@fnames) {
            # Split a filename and its path.
            @_splitted = split $prog_info{opts}->{fname_path_sep}, $glued;
            if (-e $_splitted[0]) {
                # fname => copy()
                $fnames_from_to{$_splitted[0]} = [
                    # path         => make_path()
                    $_splitted[1],
                    # path + fname => copy()
                    sprintf(
                        "%s%s%s",
                        $_splitted[1],
                        $path_delim,
                        # For a to-be-deployed fname specified with its path;
                        # e.g. ./subdir/some_file.dat
                        $_splitted[0] =~ /\\|\// ?
                            (split /\\|\//, $_splitted[0])[-1] :
                            $_splitted[0]
                    )
                ];
                $lengthiest = $_splitted[0]
                    if length($_splitted[0]) > length($lengthiest);
            }
        }
    }
    
    # (ii) Filenames with the same path
    elsif ($is_same_path == 1) {
        # Make the argument array contain filenames only.
        @fnames = grep !/$prog_info{opts}->{same_path_flag}/i, @_argv;
        foreach my $fname (@fnames) {
            if (-e $fname) {
                # fname => copy()
                $fnames_from_to{$fname} = [
                    # path  => make_path()
                    $same_path,
                    # path + fname => copy()
                    sprintf(
                        "%s%s%s",
                        $same_path,
                        $path_delim,
                        # For a filename specified with its path;
                        # e.g. ./subdir/some_file.dat
                        $fname =~ /\\|\// ?
                            (split /\\|\//, $fname)[-1] :
                            $fname
                    )
                ];
                $lengthiest = $fname if length($fname) > length($lengthiest);
            }
        }
    }
    
    #
    # Deploy the designated files following displaying.
    #
    if (%fnames_from_to) {
        say '-' x 70;
        my $_conv = '%-'.length($lengthiest).'s';
        while (my($k, $v) = each %fnames_from_to) {
            printf("$_conv => %s\n", $k, $v->[1]);
            
            # Ask whether to make_path().
            if (not -d $v->[0]) {
                print "\n[$v->[0]] does not exist.\n".
                      "Run File::Path::make_path()? (y/n)>";
                while (chomp(my $yn = <STDIN>)) {
                    last   if $yn =~ /\by\b/i;
                    return if $yn =~ /\bn\b/i;
                }
                make_path($v->[0]);
            }
            
            copy($k, $v->[1]);
        }
        say '-' x 70;
    }
    print %fnames_from_to ?
        "Deployment completed. " :
        "None of the designated files found in the current working dir.\n";
}


#
# Subroutines from My::Toolset
#
sub show_front_matter {
    my $hash_ref = shift; # Arg 1: To be %_prog_info
    
    #
    # Data type validation and deref: Arg 1
    #
    my $_sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg to [$_sub_name] must be a hash ref!"
        unless ref $hash_ref eq HASH;
    my %_prog_info = %$hash_ref;
    
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
    my $lead_symb    = '';
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
    my @_fm;
    my $k = 0;
    my $border_len = $lead_symb ? 69 : 70;
    my %borders = (
        '+' => $lead_symb.('+' x $border_len).$newline,
        '*' => $lead_symb.('*' x $border_len).$newline,
    );
    
    # Top rule
    if ($is_prog or $is_auth) {
        $_fm[$k++] = $borders{'+'};
    }
    
    # Program info, except the usage
    if ($is_prog) {
        $_fm[$k++] = sprintf(
            "%s%s %s: %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $_prog_info{titl},
            $_prog_info{vers},
            $_prog_info{expl},
            $newline
        );
        $_fm[$k++] = sprintf(
            "%s%s%s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            'Last update:'.($is_timestamp ? '  ': ' '),
            $_prog_info{date_last},
            $newline
        );
    }
    
    # Timestamp
    if ($is_timestamp) {
        my %_datetimes = construct_timestamps('-');
        $_fm[$k++] = sprintf(
            "%sCurrent time: %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $_datetimes{ymdhms},
            $newline
        );
    }
    
    # Author info
    if ($is_auth) {
        $_fm[$k++] = $lead_symb.$newline if $is_prog;
        $_fm[$k++] = sprintf(
            "%s%s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $_prog_info{auth}{$_},
            $newline
        ) for qw(name posi affi mail);
    }
    
    # Bottom rule
    if ($is_prog or $is_auth) {
        $_fm[$k++] = $borders{'+'};
    }
    
    # Program usage: Leading symbols are not used.
    if ($is_usage) {
        $_fm[$k++] = $newline if $is_prog or $is_auth;
        $_fm[$k++] = $_prog_info{usage};
    }
    
    # Feed a blank line at the end of the front matter.
    if (not $is_no_trailing_blkline) {
        $_fm[$k++] = $newline;
    }
    
    #
    # Print the front matter.
    #
    if ($is_copy) {
        return @_fm;
    }
    elsif (not $is_copy) {
        print for @_fm;
    }
}


sub validate_argv {
    my $hash_ref  = shift; # Arg 1: To be %_prog_info
    my $array_ref = shift; # Arg 2: To be @_argv
    my $num_of_req_argv;   # Arg 3: (Optional) Number of required args
    $num_of_req_argv = shift if defined $_[0];
    
    #
    # Data type validation and deref: Arg 1
    #
    my $_sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg to [$_sub_name] must be a hash ref!"
        unless ref $hash_ref eq HASH;
    my %_prog_info = %$hash_ref;
    
    #
    # Data type validation and deref: Arg 2
    #
    croak "The 2nd arg to [$_sub_name] must be an array ref!"
        unless ref $array_ref eq ARRAY;
    my @_argv = @$array_ref;
    
    #
    # Terminate the program if the number of required arguments passed
    # is not sufficient.
    # (performed only when the 3rd optional argument is given)
    #
    if ($num_of_req_argv) {
        my $num_of_req_argv_passed = grep $_ !~ /-/, @_argv;
        if ($num_of_req_argv_passed < $num_of_req_argv) {
            say $_prog_info{usage};
            say "    | You have input $num_of_req_argv_passed required args,".
                " but we need $num_of_req_argv.";
            say "    | Please refer to the usage above.";
            exit;
        }
    }
    
    #
    # Count the number of correctly passed options.
    #
    
    # Non-fnames
    my $num_of_corr_opts = 0;
    foreach my $arg (@_argv) {
        foreach my $v (values %{$_prog_info{opts}}) {
            if ($arg =~ /$v/i) {
                $num_of_corr_opts++;
                next;
            }
        }
    }
    
    # Fname-likes
    my $num_of_fnames = 0;
    $num_of_fnames = grep $_ !~ /^-/, @_argv;
    $num_of_corr_opts += $num_of_fnames;
    
    # Warn if "no" correct options have been passed.
    if ($num_of_corr_opts == 0) {
        say $_prog_info{usage};
        say "    | None of the command-line options was correct.";
        say "    | Please refer to the usage above.";
        exit;
    }
}


sub pause_shell {
    print "Press enter to exit...";
    while (<STDIN>) { last; }
}
#eof