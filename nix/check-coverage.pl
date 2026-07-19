use strict;
use warnings;

my ($index, $minimum) = @ARGV;
die "usage: $0 COVER-INDEX MINIMUM-PERCENT\n" unless defined $minimum;

open my $fh, '<', $index or die "cannot open $index: $!\n";
local $/;
my $html = <$fh>;
close $fh or die "cannot close $index: $!\n";

# sb-cover's cover-index.html has no aggregate row and prints per-file
# percentages in cells without a trailing '%' (the '%' lives only in the
# column header), e.g. "<td>29</td><td>55</td><td> 52.7</td>".  Sum the
# expression Covered/Total columns across every source-file row and derive the
# overall percentage rather than scraping a single "NN%" token that this format
# never contains.
my ($covered, $total) = (0, 0);
while ($html =~ m{text-cell'>\s*<a[^>]*>[^<]+</a>\s*</td>\s*<td>(\d+)</td>\s*<td>(\d+)</td>}g) {
    $covered += $1;
    $total   += $2;
}

if ($total == 0) {
    # Fall back to a literal "NN%" token for sb-cover variants that emit one.
    my @percentages = $html =~ /([0-9]+(?:\.[0-9]+)?)%/g;
    die "no coverage data found in $index\n" unless @percentages;
    my $actual = $percentages[-1];
    printf "coverage: %.2f%% (minimum: %.2f%%)\n", $actual, $minimum;
    die "coverage threshold not met\n" if $actual < $minimum;
    exit 0;
}

my $actual = 100 * $covered / $total;
printf "coverage: %.2f%% (%d/%d expressions, minimum: %.2f%%)\n",
    $actual, $covered, $total, $minimum;
die "coverage threshold not met\n" if $actual < $minimum;
