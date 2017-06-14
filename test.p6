use lib '.';
use WebAssembly;
use WebAssembly::Opcodes;

my $module = WebAssembly::Module.load('hello.wasm'.IO);
say ($module.code_section andthen .entries[*-1].code);
