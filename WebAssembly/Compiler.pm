use WebAssembly;

unit package WebAssembly;

multi decompile(Str $code) { $code }

multi decompile(WebAssembly::FuncType $_) {
    [~] '(', .param_types.join(', ') , ')',
        .return_count ?? " -> {.return_type}" !! '';
}

multi decompile(WebAssembly::GlobalType $_) {
    "{.content_type}"
}

multi decompile(WebAssembly::MemoryType $_) {
    "memory({ decompile .limits })";
}

multi decompile(WebAssembly::ResizableLimits $_) {
    .flags ?? "{.initial}..{.maximum}" !! "{.initial}";
}

multi decompile(WebAssembly::ImportSection $_) {
    for .entries {
        my $type = decompile .kind == WebAssembly::Function
            ?? $*module.type(.type)
            !! .type;

        take "import {.module}.{.field} : $type";
    }

    take '';
}

multi decompile(WebAssembly::ExportSection $_) {
    for .entries {
        take "export {.field}";
    }

    take '';
}

class Compiler {
    multi method decompile(WebAssembly::Module $_) {
        my $*module = $_;
        join "\n", gather {
            decompile($_) with .import_section;
            decompile($_) with .export_section;
        }
    }
}
