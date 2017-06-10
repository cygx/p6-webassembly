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

multi decompile(CodeSection $_) {
    for .entries.kv -> $pos, $_ {
        my $index = .index;
        my $type = $*module.signature($pos);
        my $name = $*module.exportname(:func, $index);
        take "fn {$name // "\$$index"}{decompile $type} \{}\n"
    }
}

my class siol is export {
    proto method decompile($) {*}

    multi method decompile(Module $_) {
        my $*module = $_;
        join "\n", gather {
            decompile($_) with .import_section;
            decompile($_) with .export_section;
            decompile($_) with .global_section;
            decompile($_) with .code_section;
        }
    }

    multi method decompile($source) {
        self.decompile(Module.load($source));
    }

    method compile(Str $code) {
        42
    }
}
