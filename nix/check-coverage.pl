use strict;
use warnings;

my ($index, $minimum, $manifest) = @ARGV;
die "usage: $0 COVER-INDEX MINIMUM-PERCENT COVERAGE-MANIFEST\n"
    unless defined $manifest;

sub normalized_basename {
    my ($path) = @_;
    $path =~ s{\\}{/}g;
    $path =~ s{^.*/}{};
    return $path;
}

sub text_content {
    my ($html) = @_;
    $html =~ s{<[^>]+>}{}g;
    $html =~ s{&amp;}{&}gi;
    $html =~ s{&lt;}{<}gi;
    $html =~ s{&gt;}{>}gi;
    $html =~ s{&quot;}{"}gi;
    $html =~ s{&#39;}{'}gi;
    $html =~ s{^\s+|\s+$}{}g;
    return $html;
}

sub decoded_text_content {
    my ($html) = @_;
    my $text = text_content($html);
    $text =~ s{&#(\d+);?}{chr($1)}eg;
    $text =~ s{&#x([0-9a-f]+);?}{chr(hex($1))}egi;
    $text =~ s{\x{a0}}{ }g;
    return $text;
}

sub source_report_html {
    my ($index_path) = @_;
    (my $directory = $index_path) =~ s{[/\\][^/\\]+\z}{};
    $directory = '.' if $directory eq $index_path;

    my %reports;
    for my $path (glob "$directory/*.html") {
        open my $fh, '<', $path or die "cannot open $path: $!\n";
        local $/;
        my $html = <$fh>;
        close $fh or die "cannot close $path: $!\n";

        my ($header) = $html =~ m{<h3>Coverage report:\s*(.*?)\s*<br\s*/?>}is;
        next unless defined $header;
        my $source = normalized_basename(decoded_text_content($header));
        die "duplicate source coverage detail for '$source' near $index_path\n"
            if exists $reports{$source};
        $reports{$source} = $html;
    }

    return \%reports;
}

sub ignored_sb_cover_artifacts {
    my ($source, $html) = @_;

    # SB-COVER records these top-level forms as uncovered even though the
    # instrumented file must execute them while loading.  It also records a
    # literal lambda-list initform as uncovered after its function is called.
    # Exclude only those source-aware artifacts; executable calls and function
    # body literals remain strict.
    my %load_time_declaration = map { $_ => 1 }
        qw(declaim in-package defclass defconstant defpackage defgeneric
           define-plist-accessor);
    my $ignored = 0;
    # The source div contains a nested line-number div, so extract the
    # enclosing nobr rather than stopping at that first closing div.
    while ($html =~ m{<nobr>(.*?)</nobr>}sig) {
        my ($line_html) = $1 =~ m{<code>\s*&#160;?(.*?)</code>\s*</div>\s*\z}is;
        next unless defined $line_html;
        next unless $line_html =~ m{class=['"]state-2['"]};
        my $line = decoded_text_content($line_html);
        if ($line =~ /^\s*\(\s*([a-z][a-z0-9-]*)\b/i
            && $load_time_declaration{lc $1}) {
            ++$ignored;
            next;
        }

        # SB-COVER resets its counters after loading these files, leaving only
        # these named load-time documentation SETFs unobservable.  Other
        # EVAL-WHEN forms and executable SETFs remain coverage requirements.
        if (($source eq 'core-utilities.lisp'
             && $line =~ /^\s*\(setf\s+\(documentation\s+'(?:unsupported-boundary-operation|unsupported-boundary-operation-operation|unsupported-boundary-operation-detail)\s+'(?:type|function)\)/i)
            || ($source eq 'core.lisp'
                && $line =~ /^\s*\(setf\s+\(documentation\s+'boundary-context\s+'type\)/i)) {
            $ignored += 3;
            next;
        }

        # This intentionally only recognizes numeric defaults inside an
        # &key or &optional lambda list, such as (start 0).  Do not widen it
        # to literals in an executable function body.
        next unless $line =~ /&(?:key|optional)\b/i;
        while ($line_html =~ m{<span\s+class=['"]state-2['"][^>]*>(.*?)</span>}sig) {
            my $parameter = decoded_text_content($1);
            ++$ignored if $parameter =~ /\A\s*\(\s*[a-z*][a-z0-9*_-]*\s+
                [+-]?\d+(?:\.\d*)?\s*\)\s*\z/ix;
        }
    }

    return $ignored;
}

open my $manifest_fh, '<', $manifest
    or die "cannot open coverage manifest $manifest: $!\n";
my %expected;
while (my $line = <$manifest_fh>) {
    chomp $line;
    $line =~ s{^\s+|\s+$}{}g;
    die "empty entry in coverage manifest $manifest\n" unless length $line;
    my $source = normalized_basename($line);
    die "duplicate source '$source' in coverage manifest $manifest\n"
        if $expected{$source};
    $expected{$source} = 1;
}
close $manifest_fh or die "cannot close coverage manifest $manifest: $!\n";
die "coverage manifest $manifest contains no sources\n" unless %expected;

open my $fh, '<', $index or die "cannot open $index: $!\n";
local $/;
my $html = <$fh>;
close $fh or die "cannot close $index: $!\n";

# sb-cover's cover-index.html has one source file per table row.  The source
# filename is linked in the first cell and the next two cells are expression
# Covered and Total counts.  Match table cells by structure rather than CSS
# classes because SBCL versions vary their class names and whitespace.
my %coverage;
while ($html =~ m{<tr\b[^>]*>(.*?)</tr>}sig) {
    my @cells = $1 =~ m{<td\b[^>]*>(.*?)</td>}sig;
    next unless @cells >= 3;

    my ($link) = $cells[0] =~ m{<a\b[^>]*>(.*?)</a>}is;
    next unless defined $link;
    my $source = normalized_basename(text_content($link));
    my $covered = text_content($cells[1]);
    my $total = text_content($cells[2]);
    next unless $covered =~ /\A\d+\z/ && $total =~ /\A\d+\z/;

    die "duplicate coverage row for '$source' in $index\n"
        if exists $coverage{$source};
    $coverage{$source} = [ $covered, $total ];
}

my @missing = sort grep { !exists $coverage{$_} } keys %expected;
die "no per-file coverage rows found in $index\n" unless %coverage;
die "coverage report is missing expected source(s): " . join(', ', @missing) . "\n"
    if @missing;

my $source_reports = source_report_html($index);
my @missing_details = sort grep { !exists $source_reports->{$_} } keys %expected;
die "coverage report is missing expected source detail(s): "
    . join(', ', @missing_details) . "\n"
    if @missing_details;

my ($covered, $total) = (0, 0);
for my $source (sort keys %expected) {
    my ($file_covered, $file_total) = @{ $coverage{$source} };
    my $ignored = ignored_sb_cover_artifacts($source, $source_reports->{$source});
    my $executable_total = $file_total - $ignored;
    die "coverage detail excludes more expressions than reported for $source\n"
        if $executable_total < $file_covered;
    my $percentage = $executable_total == 0 ? 100 : 100 * $file_covered / $executable_total;
    printf "%s: %.2f%% (%d/%d executable expressions; %d SB-COVER artifacts excluded)\n",
        $source, $percentage, $file_covered, $executable_total, $ignored;
    die "coverage is incomplete for $source\n"
        if $file_covered != $executable_total;
    $covered += $file_covered;
    $total += $executable_total;
}

my $actual = $total == 0 ? 100 : 100 * $covered / $total;
printf "coverage: %.2f%% (%d/%d expected-source expressions, minimum: %.2f%%)\n",
    $actual, $covered, $total, $minimum;
die "coverage threshold not met\n" if $actual < $minimum;
