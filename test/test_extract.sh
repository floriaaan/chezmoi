## --- Tests: extract.sh ---

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
source "$_test_repo_dir/extract.sh"

test_extract_missing_file_fails() {
    (
        cd "$(mktemp -d)" || exit 1
        assert_failure "extract d'un fichier inexistant échoue" -- extract "nope.tar.gz"
    )
}

test_extract_unknown_extension_fails() {
    (
        local tmp
        tmp=$(mktemp -d)
        cd "$tmp" || exit 1
        : > "weird.foo"
        assert_failure "extract d'une extension non reconnue échoue" -- extract "weird.foo"
    )
}

test_extract_tar_single_root_direct() {
    (
        local work archive
        work=$(mktemp -d)
        cd "$work" || exit 1
        mkdir -p src/onlydir
        echo hello > src/onlydir/file.txt
        (cd src && tar -cf ../archive.tar onlydir)
        archive="$work/archive.tar"
        mkdir extractdir && cd extractdir || exit 1
        extract "$archive" >/dev/null
        assert_success "racine unique: extrait directement sans dossier proposé" -- test -f "onlydir/file.txt"
    )
}

test_extract_tar_tarbomb_prompt_accepted() {
    (
        local work archive
        work=$(mktemp -d)
        cd "$work" || exit 1
        mkdir -p src
        echo a > src/file1.txt
        echo b > src/file2.txt
        (cd src && tar -cf ../bomb.tar file1.txt file2.txt)
        archive="$work/bomb.tar"
        mkdir extractdir && cd extractdir || exit 1
        printf 'y\n' | extract "$archive" >/dev/null
        assert_success "tarbomb accepté: dossier 'bomb/' créé" -- test -f "bomb/file1.txt"
    )
}

test_extract_tar_tarbomb_prompt_declined() {
    (
        local work archive
        work=$(mktemp -d)
        cd "$work" || exit 1
        mkdir -p src
        echo a > src/file1.txt
        echo b > src/file2.txt
        (cd src && tar -cf ../bomb.tar file1.txt file2.txt)
        archive="$work/bomb.tar"
        mkdir extractdir && cd extractdir || exit 1
        printf 'n\n' | extract "$archive" >/dev/null
        assert_success "tarbomb refusé: extraction à plat dans le dossier courant" -- test -f "file1.txt"
    )
}

test_extract_with_dest_skips_tarbomb_prompt() {
    (
        local work archive
        work=$(mktemp -d)
        cd "$work" || exit 1
        mkdir -p src
        echo a > src/file1.txt
        echo b > src/file2.txt
        (cd src && tar -cf ../bomb.tar file1.txt file2.txt)
        archive="$work/bomb.tar"
        mkdir extractdir && cd extractdir || exit 1
        extract "$archive" "out" >/dev/null
        assert_success "dest fourni: pas de prompt, extraction dans dest" -- test -f "out/file1.txt"
    )
}

test_extract_zip_single_root() {
    (
        local work archive
        work=$(mktemp -d)
        cd "$work" || exit 1
        mkdir -p src/onlydir
        echo hello > src/onlydir/file.txt
        (cd src && python3 -c "
import zipfile
zf = zipfile.ZipFile('../archive.zip', 'w')
zf.write('onlydir/file.txt')
zf.close()
")
        archive="$work/archive.zip"
        mkdir extractdir && cd extractdir || exit 1
        extract "$archive" >/dev/null
        assert_success "zip racine unique: extrait directement" -- test -f "onlydir/file.txt"
    )
}

test_extract_missing_binary_reports_which_one() {
    (
        cd "$(mktemp -d)" || exit 1
        : > "archive.7z"
        local out
        out=$(extract "archive.7z" 2>&1)
        assert_match "7z" "$out" "extract .7z sans binaire mentionne '7z'"
    )
}

test_extract_success_message() {
    (
        local work archive
        work=$(mktemp -d)
        cd "$work" || exit 1
        echo hi > file.txt
        tar -cf archive.tar file.txt
        mkdir extractdir && cd extractdir || exit 1
        local out
        out=$(extract "$work/archive.tar")
        assert_match "archive.tar.*→" "$out" "extract affiche 'archive → destination' en cas de succès"
    )
}

test_compress_tar_gz_roundtrip() {
    (
        local work
        work=$(mktemp -d)
        cd "$work" || exit 1
        mkdir data
        echo payload > data/f.txt
        compress out.tar.gz data >/dev/null
        assert_success "compress crée l'archive tar.gz" -- test -f "out.tar.gz"
        mkdir check && cd check || exit 1
        tar -xzf ../out.tar.gz
        assert_success "compress: contenu restauré au round-trip" -- test -f "data/f.txt"
    )
}

test_compress_unknown_extension_fails() {
    (
        cd "$(mktemp -d)" || exit 1
        : > "f.txt"
        assert_failure "compress vers extension inconnue échoue" -- compress "out.weird" "f.txt"
    )
}

test_compress_missing_dest_fails() {
    assert_failure "compress sans fichiers échoue" -- compress "out.tar.gz"
}
