unit package WebAssembly;
use WebAssembly::Sections;
use WebAssembly::Module;

multi decompile(Str $code) { $code }

multi decompile(FuncType $_) {
    [~] '(', .param_types.join(', ') , ')',
        .return_count ?? " -> {.return_type}" !! '';
}

multi decompile(GlobalType $_) {
    "{.content_type}"
}

multi decompile(MemoryType $_) {
    "memory({ decompile .limits })";
}

multi decompile(ResizableLimits $_) {
    .flags ?? "{.initial}..{.maximum}" !! "{.initial}";
}

multi decompile(ImportSection $_) {
    for .entries {
        my $type = decompile .kind == Function
            ?? $*module.type(.type)
            !! .type;

        take "import {.module}.{.field} : $type";
    }

    take '';
}

multi decompile(ExportSection $_) {
    for .entries {
        take "export {.field}";
    }

    take '';
}

multi decompile(GlobalSection $_) {
    for .entries.kv -> $id, $_ {
        take "global \@{$id} : {.type}";
    }

    take '';
}

class Compiler {
    multi method decompile(Module $_) {
        my $*module = $_;
        join "\n", gather {
            decompile($_) with .import_section;
            decompile($_) with .export_section;
            decompile($_) with .global_section;
        }
    }
}
