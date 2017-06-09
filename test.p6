use lib '.';
use WebAssembly;

my $blob := slurp 'hello.wasm', :bin;
.say for WebAssembly::Stream.new($blob).sections;
