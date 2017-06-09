use lib '.';
use WebAssembly;

my $blob = blob8.new(1, 2, 3);
my $stream = WebAssembly::Stream.new($blob);
say $stream.read(2);
