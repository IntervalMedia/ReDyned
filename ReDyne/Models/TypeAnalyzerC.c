#include "TypeAnalyzerC.h"
#include "MachOHeader.h"
#include "SymbolTable.h"
#include <string.h>
#include <stdlib.h>

// MARK: - Symbol Analysis Helpers

bool c_is_class_symbol(const char* name) {
    if (!name) return false;

    return strstr(name, "_OBJC_CLASS_$_") != NULL ||
           strstr(name, "_TtC") != NULL ||
           strstr(name, "objc_class") != NULL;
}

bool c_is_struct_symbol(const char* name) {
    if (!name) return false;
    
    return strstr(name, "struct") != NULL ||
           strstr(name, "Struct") != NULL ||
           strstr(name, "_struct_") != NULL;
}

bool c_is_enum_symbol(const char* name) {
    if (!name) return false;
    
    return strstr(name, "enum") != NULL ||
           strstr(name, "Enum") != NULL ||
           strstr(name, "_enum_") != NULL;
}

bool c_is_protocol_symbol(const char* name) {
    if (!name) return false;
    
    return strstr(name, "protocol") != NULL ||
           strstr(name, "Protocol") != NULL ||
           strstr(name, "_protocol_") != NULL;
}

bool c_is_function_symbol(const char* name) {
    if (!name) return false;
    
    return name[0] == '_' && 
           (strstr(name, "func") != NULL || 
            strstr(name, "method") != NULL ||
            strstr(name, "selector") != NULL);
}

bool c_is_property_symbol(const char* name, const char* typeName) {
    if (!name || !typeName) return false;
    
    return strstr(name, typeName) != NULL &&
           (strstr(name, "property") != NULL ||
            strstr(name, "field") != NULL ||
            strstr(name, "member") != NULL ||
            strstr(name, "ivar") != NULL ||
            strstr(name, "_") != NULL);
}

bool c_is_method_symbol(const char* name, const char* typeName) {
    if (!name || !typeName) return false;
    
    return strstr(name, typeName) != NULL &&
           (strstr(name, "method") != NULL ||
            strstr(name, "func") != NULL ||
            strstr(name, "selector") != NULL ||
            strstr(name, "imp") != NULL);
}

bool c_is_enum_case_symbol(const char* name, const char* enumName) {
    if (!name || !enumName) return false;
    
    return strstr(name, enumName) != NULL &&
           (strstr(name, "case") != NULL ||
            strstr(name, "value") != NULL ||
            strstr(name, "option") != NULL);
}

// MARK: - Name Extraction Helpers

char* c_extract_class_name(const char* symbolName) {
    if (!symbolName) return NULL;
    
    if (strstr(symbolName, "_OBJC_CLASS_$_")) {
        return strdup(symbolName + 14);
    }
    
    return strdup(symbolName);
}

char* c_extract_struct_name(const char* symbolName) {
    if (!symbolName) return NULL;
    
    if (strstr(symbolName, "_struct_")) {
        return strdup(symbolName + 8);
    }
    
    return strdup(symbolName);
}

char* c_extract_enum_name(const char* symbolName) {
    if (!symbolName) return NULL;
    
    if (strstr(symbolName, "_enum_")) {
        return strdup(symbolName + 6);
    }
    
    return strdup(symbolName);
}

char* c_extract_protocol_name(const char* symbolName) {
    if (!symbolName) return NULL;
    
    if (strstr(symbolName, "_protocol_")) {
        return strdup(symbolName + 10);
    }
    
    return strdup(symbolName);
}

char* c_extract_function_name(const char* symbolName) {
    if (!symbolName) return NULL;
    
    if (symbolName[0] == '_') {
        return strdup(symbolName + 1);
    }
    
    return strdup(symbolName);
}

char* c_extract_property_name(const char* name, const char* typeName) {
    if (!name || !typeName) return NULL;
    
    const char* typePos = strstr(name, typeName);
    if (typePos) {
        const char* nameStart = typePos + strlen(typeName);
        if (*nameStart == '_') {
            nameStart++;
        }
        return strdup(nameStart);
    }
    
    return strdup(name);
}

char* c_extract_method_name(const char* name, const char* typeName) {
    if (!name || !typeName) return NULL;
    
    const char* typePos = strstr(name, typeName);
    if (typePos) {
        const char* nameStart = typePos + strlen(typeName);
        if (*nameStart == '_') {
            nameStart++;
        }
        return strdup(nameStart);
    }
    
    return strdup(name);
}

char* c_extract_enum_case_name(const char* name, const char* enumName) {
    if (!name || !enumName) return NULL;
    
    const char* enumPos = strstr(name, enumName);
    if (enumPos) {
        const char* nameStart = enumPos + strlen(enumName);
        if (*nameStart == '_') {
            nameStart++;
        }
        return strdup(nameStart);
    }
    
    return strdup(name);
}

// MARK: - Type Inference Helpers

char* c_infer_property_type(const char* name, uint64_t size) {
    if (!name) return NULL;
    
    char* type = malloc(32);
    if (!type) return NULL;
    
    if (strstr(name, "string") || strstr(name, "str")) {
        strcpy(type, "String");
    } else if (strstr(name, "int") || strstr(name, "number")) {
        strcpy(type, "Int");
    } else if (strstr(name, "bool") || strstr(name, "flag")) {
        strcpy(type, "Bool");
    } else if (strstr(name, "float") || strstr(name, "double")) {
        strcpy(type, "Double");
    } else if (size == 8) {
        strcpy(type, "Int64");
    } else if (size == 4) {
        strcpy(type, "Int32");
    } else if (size == 2) {
        strcpy(type, "Int16");
    } else if (size == 1) {
        strcpy(type, "Int8");
    } else {
        strcpy(type, "Any");
    }
    
    return type;
}

char* c_infer_return_type(const char* name, uint64_t size) {
    if (!name) return NULL;
    
    char* type = malloc(32);
    if (!type) return NULL;
    
    if (strstr(name, "init") || strstr(name, "alloc")) {
        strcpy(type, "Self");
    } else if (strstr(name, "bool") || strstr(name, "flag")) {
        strcpy(type, "Bool");
    } else if (strstr(name, "string") || strstr(name, "str")) {
        strcpy(type, "String");
    } else if (strstr(name, "int") || strstr(name, "number")) {
        strcpy(type, "Int");
    } else if (strstr(name, "void") || strstr(name, "empty")) {
        strcpy(type, "Void");
    } else {
        strcpy(type, "Any");
    }
    
    return type;
}

int c_infer_access_level(const char* name) {
    if (!name) return 0;
    
    if (strstr(name, "private") || strstr(name, "_private")) {
        return 2;
    } else if (strstr(name, "fileprivate") || strstr(name, "_fileprivate")) {
        return 3;
    } else if (strstr(name, "internal") || strstr(name, "_internal")) {
        return 1;
    } else if (strstr(name, "open") || strstr(name, "_open")) {
        return 4;
    } else {
        return 0;
    }
}

// MARK: - String Parsing Helpers

bool c_contains_class_definition(const char* string) {
    if (!string) return false;
    
    return strstr(string, "class ") != NULL && strstr(string, ":") != NULL;
}

bool c_contains_struct_definition(const char* string) {
    if (!string) return false;
    
    return strstr(string, "struct ") != NULL && strstr(string, "{") != NULL;
}

bool c_contains_enum_definition(const char* string) {
    if (!string) return false;
    
    return strstr(string, "enum ") != NULL && strstr(string, "case") != NULL;
}

char* c_extract_type_name_from_string(const char* string, const char* keyword) {
    if (!string || !keyword) return NULL;
    
    char* keywordPos = strstr(string, keyword);
    if (!keywordPos) return NULL;
    
    char* nameStart = keywordPos + strlen(keyword);
    while (*nameStart == ' ') nameStart++;
    
    char* nameEnd = nameStart;
    while (*nameEnd && *nameEnd != ' ' && *nameEnd != ':' && *nameEnd != '{') {
        nameEnd++;
    }
    
    int nameLen = (int)(nameEnd - nameStart);
    if (nameLen <= 0) return NULL;
    
    char* typeName = malloc(nameLen + 1);
    if (!typeName) return NULL;
    
    strncpy(typeName, nameStart, nameLen);
    typeName[nameLen] = '\0';
    
    return typeName;
}

// MARK: - Binary Analysis Helpers

uint64_t c_estimate_class_size(const char* className) {
    if (!className) return 64;
    
    if (strstr(className, "View") || strstr(className, "Controller")) {
        return 200;
    } else if (strstr(className, "Model")) {
        return 100;
    } else if (strstr(className, "Manager")) {
        return 150;
    } else {
        return 64;
    }
}

uint64_t c_estimate_struct_size(const char* structName) {
    if (!structName) return 24;
    
    if (strstr(structName, "Point") || strstr(structName, "Size")) {
        return 16;
    } else if (strstr(structName, "Rect")) {
        return 32;
    } else if (strstr(structName, "Range")) {
        return 16;
    } else {
        return 24;
    }
}

uint64_t c_estimate_enum_size(const char* enumName) {
    if (!enumName) return 4;
    
    if (strstr(enumName, "Int") || strstr(enumName, "Raw")) {
        return 8;
    } else {
        return 4;
    }
}

// MARK: - Memory Management

void c_free_string(char* str) {
    if (str) {
        free(str);
    }
}

// MARK: - Type Reconstruction (C API)

static bool c_reconstruction_has_name(c_reconstructed_type_t *types, uint32_t count, const char *name) {
    if (!types || !name) return false;
    for (uint32_t i = 0; i < count; i++) {
        if (types[i].name && strcmp(types[i].name, name) == 0) {
            return true;
        }
    }
    return false;
}

static double c_confidence_for_symbol(const char *name, c_type_category_t category) {
    if (!name) return 0.1;
    if (strstr(name, "_OBJC_CLASS_$_")) {
        return 0.9;
    }
    if (category == C_TYPE_CATEGORY_CLASS && (strstr(name, "_TtC") || strstr(name, "_Tt"))) {
        return 0.85;
    }
    if (category == C_TYPE_CATEGORY_ENUM || category == C_TYPE_CATEGORY_STRUCT) {
        return 0.75;
    }
    if (category == C_TYPE_CATEGORY_PROTOCOL) {
        return 0.7;
    }
    return 0.6;
}

static uint64_t c_estimated_size_for_category(const char *name, c_type_category_t category) {
    switch (category) {
        case C_TYPE_CATEGORY_CLASS:
            return c_estimate_class_size(name);
        case C_TYPE_CATEGORY_STRUCT:
            return c_estimate_struct_size(name);
        case C_TYPE_CATEGORY_ENUM:
            return c_estimate_enum_size(name);
        default:
            return 0;
    }
}

c_type_reconstruction_result_t *c_reconstruct_types_from_binary(const char *binary_path) {
    if (!binary_path) return NULL;

    MachOContext *ctx = macho_open(binary_path, NULL);
    if (!ctx) return NULL;

    if (!macho_parse_header(ctx) || !macho_parse_load_commands(ctx)) {
        macho_close(ctx);
        return NULL;
    }

    SymbolTableContext *sym_ctx = symbol_table_create(ctx);
    if (!sym_ctx || !symbol_table_parse(sym_ctx)) {
        if (sym_ctx) symbol_table_free(sym_ctx);
        macho_close(ctx);
        return NULL;
    }

    c_type_reconstruction_result_t *result = calloc(1, sizeof(c_type_reconstruction_result_t));
    if (!result) {
        symbol_table_free(sym_ctx);
        macho_close(ctx);
        return NULL;
    }

    uint32_t capacity = 32;
    result->types = calloc(capacity, sizeof(c_reconstructed_type_t));
    if (!result->types) {
        free(result);
        symbol_table_free(sym_ctx);
        macho_close(ctx);
        return NULL;
    }

    for (uint32_t i = 0; i < sym_ctx->symbol_count; i++) {
        SymbolInfo *sym = &sym_ctx->symbols[i];
        if (!sym->name || sym->name[0] == '\0') continue;

        c_type_category_t category = C_TYPE_CATEGORY_UNKNOWN;
        char *type_name = NULL;

        if (c_is_class_symbol(sym->name)) {
            category = C_TYPE_CATEGORY_CLASS;
            type_name = c_extract_class_name(sym->name);
        } else if (c_is_struct_symbol(sym->name)) {
            category = C_TYPE_CATEGORY_STRUCT;
            type_name = c_extract_struct_name(sym->name);
        } else if (c_is_enum_symbol(sym->name)) {
            category = C_TYPE_CATEGORY_ENUM;
            type_name = c_extract_enum_name(sym->name);
        } else if (c_is_protocol_symbol(sym->name)) {
            category = C_TYPE_CATEGORY_PROTOCOL;
            type_name = c_extract_protocol_name(sym->name);
        }

        if (!type_name || type_name[0] == '\0') {
            c_free_string(type_name);
            continue;
        }

        if (c_reconstruction_has_name(result->types, result->type_count, type_name)) {
            c_free_string(type_name);
            continue;
        }

        if (result->type_count >= capacity) {
            capacity *= 2;
            c_reconstructed_type_t *new_types = realloc(result->types, sizeof(c_reconstructed_type_t) * capacity);
            if (!new_types) {
                c_free_string(type_name);
                break;
            }
            result->types = new_types;
        }

        c_reconstructed_type_t *entry = &result->types[result->type_count];
        entry->name = type_name;
        entry->address = sym->address;
        entry->size = c_estimated_size_for_category(type_name, category);
        entry->category = category;
        entry->confidence = c_confidence_for_symbol(sym->name, category);
        result->type_count += 1;
    }

    symbol_table_free(sym_ctx);
    macho_close(ctx);

    return result;
}

void c_free_reconstruction_result(c_type_reconstruction_result_t *result) {
    if (!result) return;
    if (result->types) {
        for (uint32_t i = 0; i < result->type_count; i++) {
            free(result->types[i].name);
        }
        free(result->types);
    }
    free(result);
}
