#!/usr/bin/perl
# Temporary target-side command for Debian's native debconf-apt-progress.
# The APT process remains the original progress-wrapper child (including PID).
use strict;
use warnings;
use IO::Handle;
use IO::Select;
use File::Basename qw(dirname);
use POSIX ();

$^F = 6;
my $self = $0;
my $dir = dirname($self);
die "Invalid temporary APT helper path\n" unless $self =~ m{^/[A-Za-z0-9_./-]+$};

sub read_text {
    my ($path) = @_;
    open my $fh, '<', $path or die "Cannot read $path: $!\n";
    local $/;
    return <$fh> // '';
}
sub decision_state {
    return -f "$dir/decision" ? read_text("$dir/decision") : '';
}
sub record_decision {
    my ($state) = @_;
    open my $fh, '>', "$dir/decision" or die "Cannot record APT decision: $!\n";
    print {$fh} $state or die "Cannot write APT decision: $!\n";
    close $fh or die "Cannot close APT decision: $!\n";
    print STDERR "APT transaction approval: $state\n";
}

# debconf-apt-progress already supplies and relays these two descriptors.
# Do not open a separate frontend, write to its parent shell's protocol, or
# replace the native package Debconf/progress mechanisms.
sub dc {
    my ($command) = @_;
    open my $out, '>&', 6 or die "Debconf write fd: $!\n";
    open my $in, '<&', 5 or die "Debconf read fd: $!\n";
    $out->autoflush(1);
    print {$out} "$command\n" or die "Debconf request failed: $!\n";
    my $reply = '';
    while (1) {
        my $n = sysread($in, my $c, 1);
        die "Debconf reply missing\n" unless defined($n) && $n == 1;
        last if $c eq "\n";
        $reply .= $c;
    }
    return $reply;
}
sub checked_dc {
    my $reply = dc($_[0]);
    die "Debconf rejected command: $reply\n" unless $reply =~ /^0(?: |$)/;
    return $reply;
}
sub encoded {
    my ($s) = @_;
    $s =~ s/[^\n]*\r//g; # omit overwritten progress counters, not transaction lines
    $s =~ s/[\x00-\x08\x0b-\x1f\x7f]//g;
    $s =~ s/\\/\\\\/g;
    $s =~ s/\n/\\n/g;
    return $s;
}
sub ask {
    my ($details) = @_;
    my $q = "my-cdd/apt-approval-$$";
    my $state = eval {
        my $heading = read_text("$dir/context");
        checked_dc("DATA $q type boolean");
        checked_dc("DATA $q description Apply these package changes?");
        checked_dc("DATA $q extended_description " . encoded("$heading\n\n$details"));
        checked_dc("SET $q false");
        checked_dc("FSET $q seen false");
        checked_dc("INPUT critical $q");
        my $go = dc('GO');
        if ($go =~ /^30(?: |$)/) { 'cancelled' }
        else {
            die "Debconf could not display approval: $go\n" unless $go =~ /^0(?: |$)/;
            my $reply = checked_dc("GET $q");
            if ($reply eq '0 true') { 'approved' }
            elsif ($reply eq '0 false') { 'declined' }
            else { die "Unexpected approval response\n"; }
        }
    };
    if ($@) { warn "APT approval unavailable: $@"; $state = 'unavailable'; }
    record_decision($state);
    return $state eq 'approved';
}

# APT can omit its ordinary yes/no prompt for explicitly requested changes.
# In that case use its actual Pre-Install-Pkgs protocol 2 action list before
# dpkg acts. Downloads may have finished. Already approved transactions do
# not prompt again. A failed or refused hook is a native APT failure.
sub preinstall {
    local $/;
    my $payload = <STDIN> // '';
    my ($header, $actions) = split /\n\n/, $payload, 2;
    die "Invalid APT pre-install protocol\n"
        unless defined($header) && $header =~ /^VERSION 2\n/ && defined($actions);
    print STDERR "Actual APT pre-install actions (protocol 2):\n$actions";
    my $state = decision_state();
    return $state eq 'approved' ? 0 : 1 if $state ne '';
    my @lines;
    for my $line (split /\n/, $actions) {
        my ($package, $old, $direction, $new, $action) = split ' ', $line, 5;
        if (defined $action) {
            $action = $action =~ m{^/} ? 'UNPACK' : $action;
            $action =~ s/^\*\*(.+)\*\*$/$1/;
            push @lines, "$package: $old $direction $new ($action)";
        } else { push @lines, $line; }
    }
    return ask("Actual package actions before dpkg runs (old version, direction, new version):\n\n"
        . join("\n", @lines) . "\n\nPackages may already have been downloaded.") ? 0 : 1;
}
exit preinstall() if @ARGV && $ARGV[0] eq '--pre-install';

# Keep APT's prompt language predictable without altering package Debconf's
# existing frontend or bypassing APT's own authentication/safety checks.
$ENV{LC_ALL} = 'C';
delete $ENV{LANGUAGE};
my $hook = "$self --pre-install";
pipe(my $apt_in, my $answer) or die "APT input pipe: $!\n";
pipe(my $output, my $apt_out) or die "APT output pipe: $!\n";
my $relay = fork();
die "APT relay fork: $!\n" unless defined $relay;
if ($relay) {
    close $answer; close $output;
    open STDIN, '<&', $apt_in or die "APT stdin: $!\n";
    open STDOUT, '>&', $apt_out or die "APT stdout: $!\n";
    open STDERR, '>&', \*STDOUT or die "APT stderr: $!\n";
    close $apt_in; close $apt_out;
    # Keep the original PID so debconf-apt-progress cancels APT itself.
    exec('apt-get', @ARGV, '-o', 'quiet=0', '-o', 'APT::Get::Assume-Yes=false',
        '-o', 'APT::Get::Show-Versions=true', '-o', 'APT::Color=false',
        '-o', 'Dpkg::Use-Pty=0', '-o', "DPkg::Pre-Install-Pkgs::=$hook",
        '-o', "DPkg::Tools::options::$self\::Version=2") or die "APT exec: $!\n";
}
# Do not keep APT's native status descriptor alive from the output relay.
POSIX::close(4);
close $apt_in; close $apt_out;
$answer->autoflush(1);
STDOUT->autoflush(1);
my $select = IO::Select->new($output, \*STDIN);
my $transcript = '';
while ($select->exists($output)) {
    for my $fh ($select->can_read()) {
        my $n = sysread($fh, my $data, 8192);
        die "APT relay read: $!\n" unless defined $n;
        if (!$n) { $select->remove($fh); next; }
        if (fileno($fh) == fileno($output)) {
            print $data;
            $transcript .= $data;
            # APT's real confirmation is flushed without a final newline.
            if ($transcript =~ /(?:^|\n)((?:Do you want to continue\?|Continue\?|Continue anyway\?) \[(?:Y\/n|y\/N)\] )$/) {
                my $prompt = $1;
                my $details = substr($transcript, 0, length($transcript)-length($prompt));
                my $ok = decision_state() eq '' && ask($details);
                print {$answer} ($ok ? "y\n" : "n\n") or die "APT response: $!\n";
                $transcript = '';
            } elsif ($transcript =~ /\[(?:Y\/n|y\/N)\] $/) {
                # Never answer yes to an unrecognized APT question.
                print {$answer} "n\n" or die "APT response: $!\n";
                $transcript = '';
            } elsif (decision_state() ne '' && length($transcript) > 1024) {
                # After a decision we only need the tail to recognize prompts.
                $transcript = substr($transcript, -1024);
            }
        } else {
            # Native debconf-apt-progress can send a media-change response.
            print {$answer} $data or die "APT media response: $!\n";
        }
    }
}
close $answer;
exit 0;
