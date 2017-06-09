use lib '.';
use WebAssembly;
use WebAssembly::Compiler;

my $module := WebAssembly::Module.load('hello.wasm'.IO);
say $module;
say WebAssembly::Compiler.decompile($module);
