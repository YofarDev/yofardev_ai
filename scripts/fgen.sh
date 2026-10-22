#!/usr/bin/env bash

# Generate a new feature's boilerplate following the FlutterForge clean
# architecture.
#
# Contract (documented in template-README.md):
#   fgen.sh <feature_name>                            # lean default
#   fgen.sh <feature_name> --with-service             # + domain coordination seam
#   fgen.sh <feature_name> --with-dto                 # + transport/domain split
#   fgen.sh <feature_name> --with-service --with-dto  # full layout
#
#   - Must run inside a FlutterForge application. The app root is resolved by
#     walking up from the current directory until a pubspec.yaml + lib/ pair
#     is found; there is no fallback project name.
#   - <feature_name> is snake_case or camelCase. It is normalized to
#     snake_case, then validated as a Dart identifier (rejects empty values,
#     separators, '..', punctuation, invalid starting characters and Dart
#     reserved identifiers).
#   - The LEAN DEFAULT generates only the layers a simple feature needs: domain
#     model (no JSON serialization), repository interface, placeholder data
#     source (returning the domain model directly), repository implementation
#     with typed results, cubit depending on the repository interface, state,
#     a single screen widget, plus repository/cubit/screen tests. The data
#     source placeholder is NOT a real transport schema — introduce
#     --with-dto when a real transport representation exists.
#   - --with-dto additionally generates the transport DTO (with JSON
#     serialization), the DTO→domain conversion, and DTO mapping tests.
#   - --with-service additionally generates a PLACEHOLDER domain service
#     between the cubit and the repository, plus its tests. The placeholder
#     must gain actual rules/coordination or be removed — a forwarding service
#     is not mandatory architecture.
#   - All output paths are computed before writing. The script refuses to run
#     if the feature's lib/ or test/ directory already exists (symlinks
#     included) — it never partially overwrites an existing feature.
#   - Files are rendered into an owned temporary directory and published only
#     afterwards. If localization or build_runner then fails, the published
#     feature is kept, the incomplete state is reported, and the script exits
#     non-zero — user changes elsewhere in the app are never touched.
#   - Screen localization keys are added through scripts/fstr.sh. Key
#     collisions are refused BEFORE anything is written (the ARB files are
#     checked up front; fstr's own collision check remains as a backstop).

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

err() {
    echo -e "${RED}Error: $*${NC}" >&2
}

usage() {
    echo "Usage: $0 <feature_name> [--with-service] [--with-dto]"
    echo ""
    echo "  (default)      lean layout: model, repository interface + impl,"
    echo "                 placeholder data source, cubit, screen, tests"
    echo "  --with-service insert a placeholder domain service (remove it or"
    echo "                 grow it into real coordination logic)"
    echo "  --with-dto     add a transport DTO with serialization and mapping"
    echo ""
    echo "Example: $0 user_profile"
    echo "Example: $0 auth --with-service --with-dto"
}

# --- 1. Arguments ---------------------------------------------------------------

if [ $# -lt 1 ]; then
    err "Feature name is required."
    echo ""
    usage
    exit 1
fi

FEATURE_NAME="$1"
WITH_SERVICE=false
WITH_DTO=false

shift
while [ $# -gt 0 ]; do
    case "$1" in
        --with-service)
            WITH_SERVICE=true
            ;;
        --with-dto)
            WITH_DTO=true
            ;;
        *)
            err "Unknown option: '$1'."
            echo ""
            usage
            exit 1
            ;;
    esac
    shift
done

if [ -z "$FEATURE_NAME" ]; then
    err "Feature name cannot be empty."
    exit 1
fi

# --- 2. Resolve the application root ---------------------------------------------

APP_ROOT=""
dir="$PWD"
while [ "$dir" != "/" ]; do
    if [ -f "$dir/pubspec.yaml" ] && [ -d "$dir/lib" ]; then
        APP_ROOT="$dir"
        break
    fi
    dir="$(dirname "$dir")"
done

if [ -z "$APP_ROOT" ]; then
    err "No Flutter application found: looked for pubspec.yaml and lib/ in the"
    err "current directory and its ancestors."
    err "Run this script from inside a FlutterForge application."
    exit 1
fi

PROJECT_NAME="$(grep -E '^name:' "$APP_ROOT/pubspec.yaml" | head -n 1 | sed -E 's/^name:[[:space:]]*//' | tr -d "\"' " || true)"
if [ -z "$PROJECT_NAME" ]; then
    err "Could not read a package name from '$APP_ROOT/pubspec.yaml'."
    exit 1
fi

# --- 3. Normalize and validate the feature name -----------------------------------

# Helper to convert snake_case to PascalCase
to_pascal() {
    printf '%s' "$1" | awk -F_ '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1' OFS=""
}

# Helper to convert snake_case to camelCase
to_camel() {
    local pascal
    pascal="$(to_pascal "$1")"
    printf '%s%s' "$(printf '%s' "${pascal:0:1}" | tr '[:upper:]' '[:lower:]')" "${pascal:1}"
}

# Convert feature name to snake_case (preserves existing snake_case, normalizes camelCase)
FEATURE_SNAKE="$(printf '%s' "$FEATURE_NAME" | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' | tr '[:upper:]' '[:lower:]')"

if ! printf '%s' "$FEATURE_SNAKE" | grep -Eq '^[a-z][a-z0-9_]*$'; then
    err "'$FEATURE_NAME' is not a valid feature name (normalized: '$FEATURE_SNAKE')."
    err "Use snake_case or camelCase: lowercase letters, digits and underscores,"
    err "starting with a letter. Empty names, path separators, '..', punctuation"
    err "and invalid starting characters are rejected."
    exit 1
fi

DART_RESERVED_IDENTIFIERS="abstract as assert async await break case catch class const continue covariant default deferred do dynamic else enum export extends extension external factory false final finally for get hide if implements import in interface is late library mixin new null on operator part required rethrow return sealed set show static super switch sync this throw true try typedef var void while with yield"
for reserved in $DART_RESERVED_IDENTIFIERS; do
    if [ "$FEATURE_SNAKE" = "$reserved" ]; then
        err "'$FEATURE_SNAKE' is a Dart reserved identifier and cannot be used as a feature name."
        exit 1
    fi
done

FEATURE_PASCAL="$(to_pascal "$FEATURE_SNAKE")"
FEATURE_CAMEL="$(to_camel "$FEATURE_SNAKE")"

# Localization keys for the generated screen. fstr.sh refuses keys that
# already exist (collision check happens before any write).
L10N_TITLE_KEY="${FEATURE_CAMEL}Title"
L10N_DATA_KEY="${FEATURE_CAMEL}Data"

# --- 4. Compute output paths; refuse existing targets ------------------------------

LIB_FEATURE_DIR="$APP_ROOT/lib/features/$FEATURE_SNAKE"
TEST_FEATURE_DIR="$APP_ROOT/test/features/$FEATURE_SNAKE"

for target in "$LIB_FEATURE_DIR" "$TEST_FEATURE_DIR"; do
    if [ -L "$target" ]; then
        err "Refusing to generate: '$target' exists and is a symlink."
        err "fgen never modifies an existing feature. Remove it or choose another name."
        exit 1
    fi
    if [ -e "$target" ]; then
        err "Refusing to generate: '$target' already exists."
        err "fgen never modifies an existing feature. Remove it or choose another name."
        exit 1
    fi
done

# --- 4b. Refuse localization key collisions BEFORE anything is written ------------
# The screen references '<feature>Title' and '<feature>Data'; fstr refuses to
# overwrite an existing key, but that refusal would only happen AFTER the
# feature files had been published. Checking the ARB files up front keeps a
# collision a clean refusal: nothing is staged, published, or generated.
for arb in "$APP_ROOT/lib/core/l10n/app_localizations_en.arb" \
           "$APP_ROOT/lib/core/l10n/app_localizations_fr.arb"; do
    for key in "$L10N_TITLE_KEY" "$L10N_DATA_KEY"; do
        if [ -f "$arb" ] && grep -Eq "\"${key}\"[[:space:]]*:" "$arb"; then
            err "Refusing to generate: localization key '$key' already exists in"
            err "$arb."
            err "fgen never overwrites localization keys. Choose another feature"
            err "name or rename the key, then re-run."
            exit 1
        fi
    done
done

echo -e "${BLUE}🚀 Generating boilerplate for feature: ${GREEN}$FEATURE_SNAKE${NC}"
echo -e "${BLUE}   Project: ${GREEN}$PROJECT_NAME${NC}"
echo -e "${BLUE}   App root: ${GREEN}$APP_ROOT${NC}"
echo -e "${BLUE}   Layout: ${GREEN}lean$( [ "$WITH_SERVICE" = true ] && printf ' + service' )$( [ "$WITH_DTO" = true ] && printf ' + dto' )${NC}"

# Templates are explicit shipped assets; render data without shell evaluation.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/feature_templates"
for template in domain_model.dart.tpl repository_contract.dart.tpl domain_service.dart.tpl remote_datasource.dart.tpl dto.dart.tpl repository_impl_imports.dart.tpl repository_impl_dto_import.dart.tpl repository_impl_body.dart.tpl state.dart.tpl cubit.dart.tpl screen.dart.tpl repository_test_imports.dart.tpl repository_test_dto_import.dart.tpl repository_test_setup.dart.tpl repository_test_dto_result.dart.tpl repository_test_domain_result.dart.tpl repository_test_body.dart.tpl dto_test.dart.tpl service_test.dart.tpl cubit_test.dart.tpl screen_test.dart.tpl; do
    if [ ! -f "$TEMPLATE_DIR/$template" ]; then
        err "Required feature template missing: $template"
        exit 1
    fi
done
[ -f "$SCRIPT_DIR/render_feature.py" ] || { err "Feature renderer missing."; exit 1; }
render_template() {
    local template="$1"
    shift
    uv run --no-project "$SCRIPT_DIR/render_feature.py" "$TEMPLATE_DIR/$template" "$@"
}

# --- 5. Render into an owned temporary directory ------------------------------------

mkdir -p "$APP_ROOT/.dart_tool"
STAGE_ROOT="$(mktemp -d "$APP_ROOT/.dart_tool/flutterforge-fgen.XXXXXX")"
cleanup() {
    rm -rf "$STAGE_ROOT"
}
trap cleanup EXIT

STAGE_LIB="$STAGE_ROOT/lib/features/$FEATURE_SNAKE"
STAGE_TEST="$STAGE_ROOT/test/features/$FEATURE_SNAKE"

echo -e "${BLUE}📂 Rendering directories...${NC}"
# NOTE: every path is quoted and passed as a single argument. Do NOT collect
# the optional directories into an unquoted variable for word splitting — an
# app root containing spaces would silently create wrong directories and the
# later template writes would fail with "No such file or directory".
mkdir -p \
    "$STAGE_LIB/data/datasources" \
    "$STAGE_LIB/data/repositories" \
    "$STAGE_LIB/domain/models" \
    "$STAGE_LIB/domain/repositories" \
    "$STAGE_LIB/presentation/bloc" \
    "$STAGE_LIB/presentation/screens" \
    "$STAGE_TEST/data/repositories" \
    "$STAGE_TEST/presentation/bloc" \
    "$STAGE_TEST/presentation/screens"
if [ "$WITH_DTO" = true ]; then
    mkdir -p "$STAGE_LIB/data/models" "$STAGE_TEST/data/models"
fi
if [ "$WITH_SERVICE" = true ]; then
    mkdir -p "$STAGE_LIB/domain/services" "$STAGE_TEST/domain/services"
fi

# --- 6. Domain Layer: Model (Freezed, lean: no JSON serialization) -------------------
# The domain model is the app's representation. Without --with-dto there is no
# transport schema to serialize against, so no fromJson/$...g.dart is emitted;
# add one only when the domain model itself must cross a persistence boundary.
render_template domain_model.dart.tpl FEATURE_PASCAL "$FEATURE_PASCAL" FEATURE_SNAKE "$FEATURE_SNAKE" > "$STAGE_LIB/domain/models/${FEATURE_SNAKE}.dart"

# --- 7. Domain Layer: Repository Interface ---
render_template repository_contract.dart.tpl FEATURE_PASCAL "$FEATURE_PASCAL" FEATURE_SNAKE "$FEATURE_SNAKE" > "$STAGE_LIB/domain/repositories/${FEATURE_SNAKE}_repository.dart"

# --- 8. Domain Layer: Service (only with --with-service) ------------------------------
if [ "$WITH_SERVICE" = true ]; then
    render_template domain_service.dart.tpl FEATURE_PASCAL "$FEATURE_PASCAL" FEATURE_SNAKE "$FEATURE_SNAKE" > "$STAGE_LIB/domain/services/${FEATURE_SNAKE}_service.dart"
fi

# --- 9. Data Layer: Data Source (interface + placeholder implementation) --------------
# The data source is the external-I/O seam. Without --with-dto the placeholder
# returns the DOMAIN model directly: there is no transport schema yet, so do
# not pretend this represents one. When a real transport appears, regenerate
# the layer with --with-dto or hand-write the DTO/conversion.
DATA_SOURCE_RETURN_TYPE="${FEATURE_PASCAL}"
DATA_SOURCE_CONSTRUCTION="const ${FEATURE_PASCAL}(id: '1', name: 'Placeholder')"
DATA_SOURCE_IMPORTS="import '../../domain/models/${FEATURE_SNAKE}.dart';"
DATA_SOURCE_RETURN_DOC="// Returns the domain model directly: the lean layout has no transport
    // representation. Replace this placeholder with real I/O (http, dio, a
    // database) when the feature gains an actual external dependency."
if [ "$WITH_DTO" = true ]; then
    DATA_SOURCE_RETURN_TYPE="${FEATURE_PASCAL}Dto"
    DATA_SOURCE_CONSTRUCTION="const ${FEATURE_PASCAL}Dto(id: '1', name: 'Placeholder')"
    DATA_SOURCE_IMPORTS="import '../models/${FEATURE_SNAKE}_dto.dart';"
    DATA_SOURCE_RETURN_DOC="// Returns the transport DTO; the repository maps it to the domain model
    // inside its guarded boundary."
fi
render_template remote_datasource.dart.tpl DATA_SOURCE_CONSTRUCTION "$DATA_SOURCE_CONSTRUCTION" DATA_SOURCE_IMPORTS "$DATA_SOURCE_IMPORTS" DATA_SOURCE_RETURN_DOC "$DATA_SOURCE_RETURN_DOC" DATA_SOURCE_RETURN_TYPE "$DATA_SOURCE_RETURN_TYPE" FEATURE_PASCAL "$FEATURE_PASCAL" > "$STAGE_LIB/data/datasources/${FEATURE_SNAKE}_remote_datasource.dart"

# --- 10. Data Layer: DTO (only with --with-dto) ---------------------------------------
if [ "$WITH_DTO" = true ]; then
    render_template dto.dart.tpl FEATURE_PASCAL "$FEATURE_PASCAL" FEATURE_SNAKE "$FEATURE_SNAKE" > "$STAGE_LIB/data/models/${FEATURE_SNAKE}_dto.dart"
fi

# --- 11. Data Layer: Repository Implementation -----------------------------------------
# Always uses typed results and the shared exception mapper; the DTO→domain
# conversion (when present) stays inside the guarded boundary so malformed
# payloads become typed failures instead of escaping exceptions.
REPO_BODY_LINES="      final ${FEATURE_PASCAL} data = await _dataSource.getData();"
if [ "$WITH_DTO" = true ]; then
    REPO_BODY_LINES="      final ${FEATURE_PASCAL}Dto dto = await _dataSource.getData();
      // DTO conversion stays inside the guarded boundary: malformed payloads
      // become a typed failure instead of escaping as an exception.
      final ${FEATURE_PASCAL} data = dto.toDomain();"
fi
render_template repository_impl_imports.dart.tpl FEATURE_SNAKE "$FEATURE_SNAKE" > "$STAGE_LIB/data/repositories/${FEATURE_SNAKE}_repository_impl.dart"
if [ "$WITH_DTO" = true ]; then
    render_template repository_impl_dto_import.dart.tpl FEATURE_SNAKE "$FEATURE_SNAKE" >> "$STAGE_LIB/data/repositories/${FEATURE_SNAKE}_repository_impl.dart"
fi
render_template repository_impl_body.dart.tpl FEATURE_PASCAL "$FEATURE_PASCAL" REPO_BODY_LINES "$REPO_BODY_LINES" >> "$STAGE_LIB/data/repositories/${FEATURE_SNAKE}_repository_impl.dart"

# --- 12. Presentation Layer: State ---
render_template state.dart.tpl FEATURE_PASCAL "$FEATURE_PASCAL" FEATURE_SNAKE "$FEATURE_SNAKE" > "$STAGE_LIB/presentation/bloc/${FEATURE_SNAKE}_state.dart"

# --- 13. Presentation Layer: Cubit ------------------------------------------------------
# The cubit depends on the repository interface directly (lean default) or on
# the domain service (--with-service) — never on another cubit.
CUBIT_DEP_TYPE="I${FEATURE_PASCAL}Repository"
CUBIT_DEP_IMPORT="'../../domain/repositories/${FEATURE_SNAKE}_repository.dart'"
if [ "$WITH_SERVICE" = true ]; then
    CUBIT_DEP_TYPE="${FEATURE_PASCAL}Service"
    CUBIT_DEP_IMPORT="'../../domain/services/${FEATURE_SNAKE}_service.dart'"
fi
render_template cubit.dart.tpl CUBIT_DEP_IMPORT "$CUBIT_DEP_IMPORT" CUBIT_DEP_TYPE "$CUBIT_DEP_TYPE" FEATURE_PASCAL "$FEATURE_PASCAL" FEATURE_SNAKE "$FEATURE_SNAKE" > "$STAGE_LIB/presentation/bloc/${FEATURE_SNAKE}_cubit.dart"

# --- 14. Presentation Layer: Screen ------------------------------------------------------
# A single screen widget: it has one responsibility (render the load
# lifecycle), so there is no Screen→View forwarding pair. The route provides
# the cubit; the screen is a pure consumer.
render_template screen.dart.tpl FEATURE_PASCAL "$FEATURE_PASCAL" FEATURE_SNAKE "$FEATURE_SNAKE" L10N_DATA_KEY "$L10N_DATA_KEY" L10N_TITLE_KEY "$L10N_TITLE_KEY" > "$STAGE_LIB/presentation/screens/${FEATURE_SNAKE}_screen.dart"

# --- 15. Test Layer: Repository Implementation Test (failure + mapping) -------------------
render_template repository_test_imports.dart.tpl FEATURE_SNAKE "$FEATURE_SNAKE" PROJECT_NAME "$PROJECT_NAME" > "$STAGE_TEST/data/repositories/${FEATURE_SNAKE}_repository_impl_test.dart"
if [ "$WITH_DTO" = true ]; then
    render_template repository_test_dto_import.dart.tpl FEATURE_SNAKE "$FEATURE_SNAKE" PROJECT_NAME "$PROJECT_NAME" >> "$STAGE_TEST/data/repositories/${FEATURE_SNAKE}_repository_impl_test.dart"
fi
render_template repository_test_setup.dart.tpl FEATURE_PASCAL "$FEATURE_PASCAL" >> "$STAGE_TEST/data/repositories/${FEATURE_SNAKE}_repository_impl_test.dart"
if [ "$WITH_DTO" = true ]; then
    render_template repository_test_dto_result.dart.tpl FEATURE_PASCAL "$FEATURE_PASCAL" >> "$STAGE_TEST/data/repositories/${FEATURE_SNAKE}_repository_impl_test.dart"
else
    render_template repository_test_domain_result.dart.tpl FEATURE_PASCAL "$FEATURE_PASCAL" >> "$STAGE_TEST/data/repositories/${FEATURE_SNAKE}_repository_impl_test.dart"
fi
render_template repository_test_body.dart.tpl FEATURE_PASCAL "$FEATURE_PASCAL" >> "$STAGE_TEST/data/repositories/${FEATURE_SNAKE}_repository_impl_test.dart"

# --- 16. Test Layer: DTO Mapping Test (only with --with-dto) -------------------------------
if [ "$WITH_DTO" = true ]; then
    render_template dto_test.dart.tpl FEATURE_PASCAL "$FEATURE_PASCAL" FEATURE_SNAKE "$FEATURE_SNAKE" PROJECT_NAME "$PROJECT_NAME" > "$STAGE_TEST/data/models/${FEATURE_SNAKE}_dto_test.dart"
fi

# --- 16b. Test Layer: Service Test (only with --with-service) ---------------------------
if [ "$WITH_SERVICE" = true ]; then
    render_template service_test.dart.tpl FEATURE_PASCAL "$FEATURE_PASCAL" FEATURE_SNAKE "$FEATURE_SNAKE" PROJECT_NAME "$PROJECT_NAME" > "$STAGE_TEST/domain/services/${FEATURE_SNAKE}_service_test.dart"
fi

# --- 17. Test Layer: Cubit Test -------------------------------------------------------------
CUBIT_TEST_MOCK_TYPE="I${FEATURE_PASCAL}Repository"
CUBIT_TEST_MOCK_IMPORT="package:$PROJECT_NAME/features/$FEATURE_SNAKE/domain/repositories/${FEATURE_SNAKE}_repository.dart"
if [ "$WITH_SERVICE" = true ]; then
    CUBIT_TEST_MOCK_TYPE="${FEATURE_PASCAL}Service"
    CUBIT_TEST_MOCK_IMPORT="package:$PROJECT_NAME/features/$FEATURE_SNAKE/domain/services/${FEATURE_SNAKE}_service.dart"
fi
render_template cubit_test.dart.tpl CUBIT_TEST_MOCK_IMPORT "$CUBIT_TEST_MOCK_IMPORT" CUBIT_TEST_MOCK_TYPE "$CUBIT_TEST_MOCK_TYPE" FEATURE_PASCAL "$FEATURE_PASCAL" FEATURE_SNAKE "$FEATURE_SNAKE" PROJECT_NAME "$PROJECT_NAME" > "$STAGE_TEST/presentation/bloc/${FEATURE_SNAKE}_cubit_test.dart"

# --- 18. Test Layer: Screen Widget Test ---------------------------------------------------
render_template screen_test.dart.tpl FEATURE_PASCAL "$FEATURE_PASCAL" FEATURE_SNAKE "$FEATURE_SNAKE" PROJECT_NAME "$PROJECT_NAME" > "$STAGE_TEST/presentation/screens/${FEATURE_SNAKE}_screen_test.dart"

# --- 19. Publish -----------------------------------------------------------------

echo -e "${GREEN}✓ Feature $FEATURE_SNAKE files rendered. Publishing...${NC}"
mkdir -p "$APP_ROOT/lib/features" "$APP_ROOT/test/features"
mv "$STAGE_LIB" "$LIB_FEATURE_DIR"
mv "$STAGE_TEST" "$TEST_FEATURE_DIR"

echo -e "${GREEN}✓ Feature $FEATURE_SNAKE files generated!${NC}"

# --- 20. Localization keys (via fstr, with collision check) -------------------------

L10N_FAILED=false
FSTR="$APP_ROOT/scripts/fstr.sh"
if [ -f "$FSTR" ]; then
    echo -e "${BLUE}🌍 Adding localization keys ($L10N_TITLE_KEY, $L10N_DATA_KEY)...${NC}"
    if ! bash "$FSTR" "$L10N_TITLE_KEY" "Exemple $FEATURE_PASCAL" "$FEATURE_PASCAL example" "$APP_ROOT"; then
        L10N_FAILED=true
    fi
    if [ "$L10N_FAILED" = false ]; then
        if ! bash "$FSTR" "$L10N_DATA_KEY" "Données : {name}" "Data: {name}" "$APP_ROOT"; then
            L10N_FAILED=true
        fi
    fi
    if [ "$L10N_FAILED" = true ]; then
        err ""
        err "Localization failed (missing key, collision, or gen-l10n error). The new"
        err "feature '$FEATURE_SNAKE' was published but is INCOMPLETE: the screen"
        err "references the '$L10N_TITLE_KEY' and '$L10N_DATA_KEY' keys."
        err "Fix the error above, then re-run:"
        err "  bash scripts/fstr.sh $L10N_TITLE_KEY \"Exemple $FEATURE_PASCAL\" \"$FEATURE_PASCAL example\""
        err "  bash scripts/fstr.sh $L10N_DATA_KEY \"Données : {name}\" \"Data: {name}\""
        exit 1
    fi
else
    err "scripts/fstr.sh not found in this application. The screen references the"
    err "localization keys '$L10N_TITLE_KEY' and '$L10N_DATA_KEY' — add them before"
    err "the app compiles:"
    err "  bash scripts/fstr.sh $L10N_TITLE_KEY \"Exemple $FEATURE_PASCAL\" \"$FEATURE_PASCAL example\""
    err "  bash scripts/fstr.sh $L10N_DATA_KEY \"Données : {name}\" \"Data: {name}\""
    exit 1
fi

# --- 21. Auto-run Build Runner -----------------------------------------------------

echo -e "${BLUE}🔧 Running build_runner to generate Freezed code...${NC}"
if command -v dart &> /dev/null; then
    if ! (cd "$APP_ROOT" && dart run build_runner build --delete-conflicting-outputs); then
        err ""
        err "build_runner failed. The new feature '$FEATURE_SNAKE' was published but is INCOMPLETE."
        err "Published files: '$LIB_FEATURE_DIR' and '$TEST_FEATURE_DIR'."
        err "Fix the errors above, then re-run: dart run build_runner build --delete-conflicting-outputs"
        exit 1
    fi
    echo -e "${GREEN}✓ Code generation complete. No more analyze errors!${NC}"

    # Format ONLY the files this script just generated. Line wrapping depends
    # on the feature-name length, so the source templates cannot be
    # formatter-exact for every name; this step makes them compliant for any
    # name. It never touches user files (fverify's format gate stays
    # non-mutating by construction).
    echo -e "${BLUE}🎨 Formatting the generated files...${NC}"
    if ! (cd "$APP_ROOT" && dart format "$LIB_FEATURE_DIR" "$TEST_FEATURE_DIR"); then
        err "dart format failed on the generated files. The feature was published"
        err "but is INCOMPLETE. Fix the errors above, then re-run:"
        err "  dart format '$LIB_FEATURE_DIR' '$TEST_FEATURE_DIR'"
        exit 1
    fi
else
    echo -e "${RED}⚠️  Warning: 'dart' command not found. Run build_runner manually.${NC}" >&2
fi

# --- 22. Next steps (DI + route wiring, per layout) ----------------------------------

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "${BLUE}⚠️  IMPORTANT: a scaffold that passes its unit tests is NOT a routed feature.${NC}"
echo -e "It only appears in the app once the DI and route steps below are applied —"
echo -e "run ${GREEN}fverify${NC} after wiring to smoke-test it end to end."
echo ""
echo -e "1. Register dependencies in ${GREEN}lib/core/di/service_locator.dart${NC}:"
echo -e "   getIt.registerLazySingleton<I${FEATURE_PASCAL}RemoteDataSource>(() => ${FEATURE_PASCAL}RemoteDataSource());"
echo -e "   getIt.registerLazySingleton<I${FEATURE_PASCAL}Repository>(() => ${FEATURE_PASCAL}Repository(getIt<I${FEATURE_PASCAL}RemoteDataSource>()));"
if [ "$WITH_SERVICE" = true ]; then
    echo -e "   getIt.registerLazySingleton<${FEATURE_PASCAL}Service>(() => ${FEATURE_PASCAL}Service(getIt<I${FEATURE_PASCAL}Repository>()));"
    echo -e "   (${FEATURE_PASCAL}Service is a PLACEHOLDER: grow it into real coordination logic or remove it)"
    echo -e "   getIt.registerFactory<${FEATURE_PASCAL}Cubit>(() => ${FEATURE_PASCAL}Cubit(getIt<${FEATURE_PASCAL}Service>()));"
else
    echo -e "   getIt.registerFactory<${FEATURE_PASCAL}Cubit>(() => ${FEATURE_PASCAL}Cubit(getIt<I${FEATURE_PASCAL}Repository>()));"
fi
echo -e "2. Add the route in ${GREEN}lib/core/router/app_router.dart${NC} — the route provides the cubit:"
echo -e "   GoRoute("
echo -e "     path: Routes.${FEATURE_CAMEL},"
echo -e "     name: '${FEATURE_PASCAL}',"
echo -e "     builder: (context, state) => BlocProvider<${FEATURE_PASCAL}Cubit>("
echo -e "       create: (_) => getIt<${FEATURE_PASCAL}Cubit>()..loadData(),"
echo -e "       child: const ${FEATURE_PASCAL}Screen(),"
echo -e "     ),"
echo -e "   )"
echo -e "   ...and the constant in ${GREEN}lib/core/router/route_constants.dart${NC}:"
echo -e "   static const String ${FEATURE_CAMEL} = '/${FEATURE_SNAKE}';"
echo -e "3. Update ${GREEN}test/core/di/service_locator_test.dart${NC} with the new registrations."
echo -e "4. Replace the placeholder data source in ${GREEN}lib/features/$FEATURE_SNAKE/data/datasources/${FEATURE_SNAKE}_remote_datasource.dart${NC} with real I/O."
if [ "$WITH_DTO" = false ]; then
    echo -e "   The lean layout has no transport schema; when a real one appears, hand-write"
    echo -e "   the DTO + conversion (or use --with-dto on a scratch name as a reference)."
fi
if [ "$WITH_SERVICE" = true ]; then
    echo -e "5. ${FEATURE_PASCAL}Service must gain actual rules/coordination or be removed — a forwarding service is not mandatory architecture."
    echo -e "6. Run ${GREEN}fverify${NC} before finishing."
else
    echo -e "5. Run ${GREEN}fverify${NC} before finishing."
fi
echo ""
