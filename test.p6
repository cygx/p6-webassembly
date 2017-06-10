use lib '.';
use WebAssembly::Siol;

say siol.decompile('hello.wasm'.IO);
