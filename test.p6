use lib '.';
use WebAssembly::Siol;

print siol.decompile('hello.wasm'.IO);
