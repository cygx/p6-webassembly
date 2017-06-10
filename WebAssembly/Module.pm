unit package WebAssembly;
use WebAssembly::Sections;
use WebAssembly::Stream;

class Module is export {
    has $.type_section;
    has $.import_section;
    has $.function_section;
    has $.table_section;
    has $.memory_section;
    has $.global_section;
    has $.export_section;
    has $.start_section;
    has $.element_section;
    has $.code_section;
    has $.data_section;
    has @.custom_sections;

    multi method load(IO::Path $path) {
        self.load(Stream.new($path.slurp(:bin)));
    }
    multi method load(Stream $stream) {
        my $module = self.bless;
        $module.add($_) for $stream.sections;
        $module;
    }

    method type($id) {
        $!type_section.?entries[$id]
    }

    method add(Section $_) {
        when TypeSection { $!type_section = $_ }
        when ImportSection { $!import_section = $_ }
        when FunctionSection { $!function_section = $_ }
        when TableSection { $!table_section = $_ }
        when MemorySection { $!memory_section = $_ }
        when GlobalSection { $!global_section = $_ }
        when ExportSection { $!export_section = $_ }
        when StartSection { $!start_section = $_ }
        when ElementSection { $!element_section = $_ }
        when CodeSection { $!code_section = $_ }
        when DataSection { $!data_section = $_ }
        when CustomSection { @!custom_sections.push($_) }
        default { warn "unsuppoted section {.^name}" }
    }

    method assemble { !!! }
}
