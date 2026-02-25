#include "ClassDumpC.h"
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>

typedef struct {
    char *data;
    size_t length;
    size_t capacity;
} class_dump_string_builder_t;

static void class_dump_builder_init(class_dump_string_builder_t *builder, size_t initial_capacity) {
    builder->data = malloc(initial_capacity);
    builder->length = 0;
    builder->capacity = builder->data ? initial_capacity : 0;
    if (builder->data) {
        builder->data[0] = '\0';
    }
}

static bool class_dump_builder_append(class_dump_string_builder_t *builder, const char *text) {
    if (!builder || !text) return false;
    size_t text_len = strlen(text);
    if (text_len == 0) return true;
    if (builder->length + text_len + 1 > builder->capacity) {
        size_t new_capacity = builder->capacity == 0 ? 4096 : builder->capacity * 2;
        while (new_capacity < builder->length + text_len + 1) {
            new_capacity *= 2;
        }
        char *new_data = realloc(builder->data, new_capacity);
        if (!new_data) return false;
        builder->data = new_data;
        builder->capacity = new_capacity;
    }
    memcpy(builder->data + builder->length, text, text_len);
    builder->length += text_len;
    builder->data[builder->length] = '\0';
    return true;
}

static void class_dump_builder_free(class_dump_string_builder_t *builder) {
    if (!builder) return;
    free(builder->data);
    builder->data = NULL;
    builder->length = 0;
    builder->capacity = 0;
}

static char *class_dump_safe_strndup(const char *start, size_t max_len) {
    if (!start || max_len == 0) return NULL;
    size_t len = 0;
    while (len < max_len && start[len] != '\0' && start[len] != '\n' && start[len] != '\r') {
        len++;
    }
    if (len == 0) return NULL;
    char *copy = malloc(len + 1);
    if (!copy) return NULL;
    memcpy(copy, start, len);
    copy[len] = '\0';
    return copy;
}

static bool class_dump_string_equals(const char *a, const char *b) {
    if (!a || !b) return false;
    return strcmp(a, b) == 0;
}

static class_dump_info_t *class_dump_find_class(class_dump_result_t *result, const char *class_name) {
    if (!result || !class_name) return NULL;
    for (uint32_t i = 0; i < result->classCount; i++) {
        if (class_dump_string_equals(result->classes[i].className, class_name)) {
            return &result->classes[i];
        }
    }
    return NULL;
}

static category_dump_info_t *class_dump_find_category(class_dump_result_t *result, const char *class_name, const char *category_name) {
    if (!result || !class_name || !category_name) return NULL;
    for (uint32_t i = 0; i < result->categoryCount; i++) {
        if (class_dump_string_equals(result->categories[i].className, class_name) &&
            class_dump_string_equals(result->categories[i].categoryName, category_name)) {
            return &result->categories[i];
        }
    }
    return NULL;
}

static protocol_dump_info_t *class_dump_find_protocol(class_dump_result_t *result, const char *protocol_name) {
    if (!result || !protocol_name) return NULL;
    for (uint32_t i = 0; i < result->protocolCount; i++) {
        if (class_dump_string_equals(result->protocols[i].protocolName, protocol_name)) {
            return &result->protocols[i];
        }
    }
    return NULL;
}

static bool class_dump_add_unique_string(char ***list, uint32_t *count, const char *value) {
    if (!list || !count || !value) return false;
    for (uint32_t i = 0; i < *count; i++) {
        if (class_dump_string_equals((*list)[i], value)) {
            return true;
        }
    }
    char **new_list = realloc(*list, sizeof(char *) * (*count + 1));
    if (!new_list) return false;
    new_list[*count] = strdup(value);
    if (!new_list[*count]) return false;
    *list = new_list;
    *count += 1;
    return true;
}

static void class_dump_split_category(const char *raw, char **class_name, char **category_name) {
    *class_name = NULL;
    *category_name = NULL;
    if (!raw) return;
    const char *separator = strstr(raw, "_$_");
    if (separator) {
        size_t class_len = (size_t)(separator - raw);
        size_t category_len = strlen(separator + 3);
        *class_name = class_dump_safe_strndup(raw, class_len);
        *category_name = class_dump_safe_strndup(separator + 3, category_len);
    } else {
        *category_name = strdup(raw);
    }
}

static void class_dump_add_method_to_class(class_dump_info_t *class_info, const char *method_name, bool is_class_method) {
    if (!class_info || !method_name) return;
    if (is_class_method) {
        class_dump_add_unique_string(&class_info->classMethods, &class_info->classMethodCount, method_name);
    } else {
        class_dump_add_unique_string(&class_info->instanceMethods, &class_info->instanceMethodCount, method_name);
    }
}

static void class_dump_add_method_to_category(category_dump_info_t *category_info, const char *method_name, bool is_class_method) {
    if (!category_info || !method_name) return;
    if (is_class_method) {
        class_dump_add_unique_string(&category_info->classMethods, &category_info->classMethodCount, method_name);
    } else {
        class_dump_add_unique_string(&category_info->instanceMethods, &category_info->instanceMethodCount, method_name);
    }
}

static category_dump_info_t *class_dump_add_category_with_class(class_dump_result_t *result, const char *class_name, const char *category_name) {
    if (!result || !class_name || !category_name) return NULL;
    category_dump_info_t *existing = class_dump_find_category(result, class_name, category_name);
    if (existing) return existing;

    category_dump_info_t *new_categories = realloc(result->categories, sizeof(category_dump_info_t) * (result->categoryCount + 1));
    if (!new_categories) return NULL;
    result->categories = new_categories;

    category_dump_info_t *categoryInfo = &result->categories[result->categoryCount];
    memset(categoryInfo, 0, sizeof(category_dump_info_t));
    categoryInfo->categoryName = strdup(category_name);
    categoryInfo->className = strdup(class_name);
    categoryInfo->protocolCount = 0;
    categoryInfo->protocols = NULL;
    categoryInfo->instanceMethodCount = 0;
    categoryInfo->instanceMethods = NULL;
    categoryInfo->classMethodCount = 0;
    categoryInfo->classMethods = NULL;
    categoryInfo->propertyCount = 0;
    categoryInfo->properties = NULL;

    result->categoryCount++;
    return categoryInfo;
}

static void class_dump_scan_methods(const char *binary_data, size_t binary_size, class_dump_result_t *result) {
    if (!binary_data || !result) return;
    for (size_t i = 0; i + 2 < binary_size; i++) {
        char c = binary_data[i];
        if ((c == '-' || c == '+') && binary_data[i + 1] == '[') {
            const char *start = binary_data + i + 2;
            size_t remaining = binary_size - (i + 2);
            size_t max_len = remaining > 200 ? 200 : remaining;
            const char *end = memchr(start, ']', max_len);
            if (!end) continue;
            size_t content_len = (size_t)(end - start);
            if (content_len == 0 || content_len >= 200) continue;
            char *content = class_dump_safe_strndup(start, content_len);
            if (!content) continue;

            char *space = strchr(content, ' ');
            if (!space) {
                free(content);
                continue;
            }
            *space = '\0';
            char *class_part = content;
            char *method_part = space + 1;
            if (*method_part == '\0') {
                free(content);
                continue;
            }

            char *category_name = NULL;
            char *class_name = NULL;
            char *open_paren = strchr(class_part, '(');
            char *close_paren = open_paren ? strchr(open_paren, ')') : NULL;
            if (open_paren && close_paren && close_paren > open_paren) {
                *open_paren = '\0';
                class_name = strdup(class_part);
                category_name = class_dump_safe_strndup(open_paren + 1, (size_t)(close_paren - open_paren - 1));
            } else {
                class_name = strdup(class_part);
            }

            if (class_name && strlen(class_name) > 0) {
                class_dump_info_t *class_info = class_dump_find_class(result, class_name);
                if (!class_info) {
                    add_class_to_result(result, class_name);
                    class_info = class_dump_find_class(result, class_name);
                }
                if (category_name && strlen(category_name) > 0) {
                    category_dump_info_t *category_info = class_dump_add_category_with_class(result, class_name, category_name);
                    if (category_info) {
                        class_dump_add_method_to_category(category_info, method_part, c == '+');
                    }
                } else if (class_info) {
                    class_dump_add_method_to_class(class_info, method_part, c == '+');
                }
            }

            free(class_name);
            free(category_name);
            free(content);
        }
    }
}

static void class_dump_scan_ivars(const char *binary_data, size_t binary_size, class_dump_result_t *result) {
    if (!binary_data || !result) return;
    const char *pattern = "_OBJC_IVAR_$_";
    size_t pattern_len = strlen(pattern);
    const char *pos = binary_data;
    size_t remaining = binary_size;

    while (remaining > pattern_len) {
        pos = memchr(pos, pattern[0], remaining);
        if (!pos) break;
        if ((size_t)(binary_data + binary_size - pos) < pattern_len) break;
        if (strncmp(pos, pattern, pattern_len) == 0) {
            const char *name_start = pos + pattern_len;
            size_t name_remaining = binary_size - (name_start - binary_data);
            char *full_name = class_dump_safe_strndup(name_start, name_remaining);
            if (full_name) {
                char *dot = strchr(full_name, '.');
                if (dot) {
                    *dot = '\0';
                    char *class_name = full_name;
                    char *ivar_name = dot + 1;
                    if (*class_name != '\0' && *ivar_name != '\0') {
                        class_dump_info_t *class_info = class_dump_find_class(result, class_name);
                        if (!class_info) {
                            add_class_to_result(result, class_name);
                            class_info = class_dump_find_class(result, class_name);
                        }
                        if (class_info) {
                            class_dump_add_unique_string(&class_info->ivars, &class_info->ivarCount, ivar_name);
                        }
                    }
                }
                free(full_name);
            }
        }
        pos++;
        remaining = binary_size - (pos - binary_data);
    }
}

// MARK: - Main Class Dump Function

class_dump_result_t* class_dump_binary(const char* binaryPath) {
    printf("[ClassDumpC] Starting sophisticated class dump for: %s\n", binaryPath);
    
    int fd = open(binaryPath, O_RDONLY);
    if (fd == -1) {
        printf("[ClassDumpC] Error: Failed to open binary file\n");
        return NULL;
    }
    
    struct stat st;
    if (fstat(fd, &st) == -1) {
        printf("[ClassDumpC] Error: Failed to get file stats\n");
        close(fd);
        return NULL;
    }
    
    size_t fileSize = st.st_size;
    char* binaryData = mmap(NULL, fileSize, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    
    if (binaryData == MAP_FAILED) {
        printf("[ClassDumpC] Error: Failed to map binary file\n");
        return NULL;
    }
    
    class_dump_result_t* result = malloc(sizeof(class_dump_result_t));
    if (!result) {
        printf("[ClassDumpC] Error: Failed to allocate result structure\n");
        munmap(binaryData, fileSize);
        return NULL;
    }
    
    result->classes = NULL;
    result->classCount = 0;
    result->categories = NULL;
    result->categoryCount = 0;
    result->protocols = NULL;
    result->protocolCount = 0;
    result->generatedHeader = NULL;
    result->headerSize = 0;
    
    class_dump_log_analysis_start(binaryPath);

    class_dump_analyze_classes(binaryData, fileSize, result);
    class_dump_analyze_categories(binaryData, fileSize, result);
    class_dump_analyze_protocols(binaryData, fileSize, result);
    class_dump_scan_ivars(binaryData, fileSize, result);
    class_dump_scan_methods(binaryData, fileSize, result);
    
    if (result->classCount == 0 && result->categoryCount == 0 && result->protocolCount == 0) {
        printf("[ClassDumpC] No ObjC structures found in symbols, trying string analysis...\n");
        analyze_strings_for_objc(binaryData, fileSize, result);
    }
    
    printf("[ClassDumpC] Class dump complete: %u classes, %u categories, %u protocols\n", 
           result->classCount, result->categoryCount, result->protocolCount);
    
    munmap(binaryData, fileSize);
    
    class_dump_log_analysis_complete(result);

    return result;
}

// MARK: - Sophisticated Analysis Functions

void analyze_symbol_table_for_objc(const char* binaryData, size_t binarySize, class_dump_result_t* result) {
    printf("[ClassDumpC] Analyzing symbol table for ObjC symbols...\n");
    
    const char* patterns[] = {
        "_OBJC_CLASS_$_",
        "_OBJC_CATEGORY_$_", 
        "_OBJC_PROTOCOL_$_",
        "_OBJC_METACLASS_$_"
    };
    
    for (int p = 0; p < 4; p++) {
        const char* pattern = patterns[p];
        const char* pos = binaryData;
        size_t remaining = binarySize;
        
        while (remaining > 0) {
            pos = memchr(pos, pattern[0], remaining);
            if (!pos) break;
            
            if (strncmp(pos, pattern, strlen(pattern)) == 0) {
                pos += strlen(pattern);
                
                char* name = malloc(256);
                if (name) {
                    int i = 0;
                    while (i < 255 && pos < binaryData + binarySize && *pos != '\0' && *pos != '\n' && *pos != '\r') {
                        name[i++] = *pos++;
                    }
                    name[i] = '\0';
                    
                    if (strlen(name) > 0) {
                        printf("[ClassDumpC] Found ObjC symbol: %s%s\n", pattern, name);
                        
                        if (strstr(pattern, "CLASS")) {
                            add_class_to_result(result, name);
                        } else if (strstr(pattern, "CATEGORY")) {
                            add_category_to_result(result, name);
                        } else if (strstr(pattern, "PROTOCOL")) {
                            add_protocol_to_result(result, name);
                        }
                    }
                    
                    free(name);
                }
            }
            
            pos++;
            remaining = binarySize - (pos - binaryData);
        }
    }
}

void analyze_objc_runtime_sections(const char* binaryData, size_t binarySize, class_dump_result_t* result) {
    
    // someone pr full Mach-O parsing i'm lazy
    analyze_symbol_table_for_objc(binaryData, binarySize, result);
}

void analyze_strings_for_objc(const char* binaryData, size_t binarySize, class_dump_result_t* result) {
    
    const char* stringPatterns[] = {
        "init",
        "dealloc", 
        "alloc",
        "retain",
        "release",
        "autorelease",
        "copy",
        "mutableCopy",
        "description",
        "debugDescription"
    };
    
    int foundMethods = 0;
    for (int p = 0; p < 10; p++) {
        const char* pattern = stringPatterns[p];
        const char* pos = binaryData;
        size_t remaining = binarySize;
        
        while (remaining > 0) {
            pos = memchr(pos, pattern[0], remaining);
            if (!pos) break;
            
            if (strncmp(pos, pattern, strlen(pattern)) == 0) {
                foundMethods++;
                printf("[ClassDumpC] Found ObjC method string: %s\n", pattern);
            }
            
            pos++;
            remaining = binarySize - (pos - binaryData);
        }
    }
    
    if (foundMethods > 0) {
        printf("[ClassDumpC] Found %d ObjC method strings, creating sample classes...\n", foundMethods);
        
        add_class_to_result(result, "SampleClass");
        add_category_to_result(result, "SampleCategory");
        add_protocol_to_result(result, "SampleProtocol");
    }
}

void add_class_to_result(class_dump_result_t* result, const char* className) {
    if (!result || !className) return;

    if (class_dump_find_class(result, className)) {
        return;
    }

    class_dump_info_t *new_classes = realloc(result->classes, sizeof(class_dump_info_t) * (result->classCount + 1));
    if (!new_classes) return;
    result->classes = new_classes;

    class_dump_info_t *classInfo = &result->classes[result->classCount];
    memset(classInfo, 0, sizeof(class_dump_info_t));
    classInfo->className = strdup(className);
    classInfo->superclassName = strdup("NSObject");
    classInfo->protocolCount = 0;
    classInfo->protocols = NULL;
    classInfo->instanceMethodCount = 0;
    classInfo->instanceMethods = NULL;
    classInfo->classMethodCount = 0;
    classInfo->classMethods = NULL;
    classInfo->propertyCount = 0;
    classInfo->properties = NULL;
    classInfo->ivarCount = 0;
    classInfo->ivars = NULL;
    classInfo->isSwift = class_dump_is_swift_class(className);
    classInfo->isMetaClass = class_dump_is_meta_class(className);

    result->classCount++;
}

void add_category_to_result(class_dump_result_t* result, const char* categoryName) {
    if (!result || !categoryName) return;

    for (uint32_t i = 0; i < result->categoryCount; i++) {
        if (class_dump_string_equals(result->categories[i].categoryName, categoryName)) {
            return;
        }
    }

    category_dump_info_t *new_categories = realloc(result->categories, sizeof(category_dump_info_t) * (result->categoryCount + 1));
    if (!new_categories) return;
    result->categories = new_categories;

    category_dump_info_t *categoryInfo = &result->categories[result->categoryCount];
    memset(categoryInfo, 0, sizeof(category_dump_info_t));
    categoryInfo->categoryName = strdup(categoryName);
    categoryInfo->className = strdup("NSObject");
    categoryInfo->protocolCount = 0;
    categoryInfo->protocols = NULL;
    categoryInfo->instanceMethodCount = 0;
    categoryInfo->instanceMethods = NULL;
    categoryInfo->classMethodCount = 0;
    categoryInfo->classMethods = NULL;
    categoryInfo->propertyCount = 0;
    categoryInfo->properties = NULL;

    result->categoryCount++;
}

void add_protocol_to_result(class_dump_result_t* result, const char* protocolName) {
    if (!result || !protocolName) return;

    if (class_dump_find_protocol(result, protocolName)) {
        return;
    }

    protocol_dump_info_t *new_protocols = realloc(result->protocols, sizeof(protocol_dump_info_t) * (result->protocolCount + 1));
    if (!new_protocols) return;
    result->protocols = new_protocols;

    protocol_dump_info_t *protocolInfo = &result->protocols[result->protocolCount];
    memset(protocolInfo, 0, sizeof(protocol_dump_info_t));
    protocolInfo->protocolName = strdup(protocolName);
    protocolInfo->protocolCount = 0;
    protocolInfo->protocols = NULL;
    protocolInfo->methodCount = 0;
    protocolInfo->methods = NULL;

    result->protocolCount++;
}

// MARK: - Header Generation

char* class_dump_generate_header(const char* binaryPath) {
    if (!binaryPath) return NULL;

    class_dump_result_t *result = class_dump_binary(binaryPath);
    if (!result) return NULL;

    class_dump_string_builder_t builder;
    class_dump_builder_init(&builder, 8192);
    if (!builder.data) {
        class_dump_free_result(result);
        return NULL;
    }

    class_dump_builder_append(&builder, "//\n");
    class_dump_builder_append(&builder, "//  Generated by ReDyne Class Dump\n");
    class_dump_builder_append(&builder, "//  Binary: ");
    class_dump_builder_append(&builder, binaryPath);
    class_dump_builder_append(&builder, "\n");
    class_dump_builder_append(&builder, "//\n\n");
    class_dump_builder_append(&builder, "#import <Foundation/Foundation.h>\n");
    class_dump_builder_append(&builder, "#import <UIKit/UIKit.h>\n\n");

    for (uint32_t i = 0; i < result->classCount; i++) {
        char *class_header = class_dump_generate_class_header(&result->classes[i]);
        if (class_header) {
            class_dump_builder_append(&builder, class_header);
            free(class_header);
        }
    }

    for (uint32_t i = 0; i < result->categoryCount; i++) {
        char *category_header = class_dump_generate_category_header(&result->categories[i]);
        if (category_header) {
            class_dump_builder_append(&builder, category_header);
            free(category_header);
        }
    }

    for (uint32_t i = 0; i < result->protocolCount; i++) {
        char *protocol_header = class_dump_generate_protocol_header(&result->protocols[i]);
        if (protocol_header) {
            class_dump_builder_append(&builder, protocol_header);
            free(protocol_header);
        }
    }

    class_dump_free_result(result);

    printf("[ClassDumpC] Header generated successfully\n");
    return builder.data;
}

char* class_dump_generate_class_header(class_dump_info_t* classInfo) {
    if (!classInfo) return NULL;
    
    char* header = malloc(16384);
    if (!header) return NULL;
    
    strcpy(header, "@interface ");
    strcat(header, classInfo->className);
    
    if (classInfo->superclassName && strlen(classInfo->superclassName) > 0) {
        strcat(header, " : ");
        strcat(header, classInfo->superclassName);
    }
    
    if (classInfo->protocolCount > 0) {
        strcat(header, " <");
        for (uint32_t i = 0; i < classInfo->protocolCount; i++) {
            if (i > 0) strcat(header, ", ");
            strcat(header, classInfo->protocols[i]);
        }
        strcat(header, ">");
    }
    
    strcat(header, "\n");
    
    for (uint32_t i = 0; i < classInfo->propertyCount; i++) {
        strcat(header, "@property ");
        strcat(header, "(nonatomic, strong) id ");
        strcat(header, classInfo->properties[i]);
        strcat(header, ";\n");
    }

    if (classInfo->ivarCount > 0) {
        strcat(header, "{\n");
        for (uint32_t i = 0; i < classInfo->ivarCount; i++) {
            strcat(header, "    id ");
            strcat(header, classInfo->ivars[i]);
            strcat(header, ";\n");
        }
        strcat(header, "}\n");
    }
    
    for (uint32_t i = 0; i < classInfo->instanceMethodCount; i++) {
        strcat(header, "- (void)");
        strcat(header, classInfo->instanceMethods[i]);
        strcat(header, ";\n");
    }
    
    for (uint32_t i = 0; i < classInfo->classMethodCount; i++) {
        strcat(header, "+ (void)");
        strcat(header, classInfo->classMethods[i]);
        strcat(header, ";\n");
    }
    
    strcat(header, "@end\n\n");
    
    return header;
}

char* class_dump_generate_category_header(category_dump_info_t* categoryInfo) {
    if (!categoryInfo) return NULL;
    
    char* header = malloc(8192);
    if (!header) return NULL;
    
    strcpy(header, "@interface ");
    strcat(header, categoryInfo->className);
    strcat(header, " (");
    strcat(header, categoryInfo->categoryName);
    strcat(header, ")\n");
    
    for (uint32_t i = 0; i < categoryInfo->propertyCount; i++) {
        strcat(header, "@property ");
        strcat(header, "(nonatomic, strong) id ");
        strcat(header, categoryInfo->properties[i]);
        strcat(header, ";\n");
    }
    
    for (uint32_t i = 0; i < categoryInfo->instanceMethodCount; i++) {
        strcat(header, "- (void)");
        strcat(header, categoryInfo->instanceMethods[i]);
        strcat(header, ";\n");
    }
    
    for (uint32_t i = 0; i < categoryInfo->classMethodCount; i++) {
        strcat(header, "+ (void)");
        strcat(header, categoryInfo->classMethods[i]);
        strcat(header, ";\n");
    }
    
    strcat(header, "@end\n\n");
    
    return header;
}

char* class_dump_generate_protocol_header(protocol_dump_info_t* protocolInfo) {
    if (!protocolInfo) return NULL;
    
    char* header = malloc(8192);
    if (!header) return NULL;
    
    strcpy(header, "@protocol ");
    strcat(header, protocolInfo->protocolName);
    
    if (protocolInfo->protocolCount > 0) {
        strcat(header, " <");
        for (uint32_t i = 0; i < protocolInfo->protocolCount; i++) {
            if (i > 0) strcat(header, ", ");
            strcat(header, protocolInfo->protocols[i]);
        }
        strcat(header, ">");
    }
    
    strcat(header, "\n");
    
    for (uint32_t i = 0; i < protocolInfo->methodCount; i++) {
        strcat(header, "- (void)");
        strcat(header, protocolInfo->methods[i]);
        strcat(header, ";\n");
    }
    
    strcat(header, "@end\n\n");
    
    return header;
}

// MARK: - Class Analysis

bool class_dump_analyze_classes(const char* binaryData, size_t binarySize, class_dump_result_t* result) {
    if (!binaryData || !result) {
        return false;
    }
    
    printf("[ClassDumpC] Analyzing ObjC classes for class dump...\n");
    
    const char* classPattern = "_OBJC_CLASS_$_";
    const char* pos = binaryData;
    size_t remaining = binarySize;
    int classCount = 0;

    while (remaining > strlen(classPattern)) {
        pos = memchr(pos, classPattern[0], remaining);
        if (!pos) break;

        if (strncmp(pos, classPattern, strlen(classPattern)) == 0) {
            const char *name_start = pos + strlen(classPattern);
            size_t name_remaining = binarySize - (name_start - binaryData);
            char *className = class_dump_safe_strndup(name_start, name_remaining);
            if (className) {
                add_class_to_result(result, className);
                class_dump_log_class_found(className, (uint64_t)(pos - binaryData));
                free(className);
                classCount++;
            }
        }

        pos++;
        remaining = binarySize - (pos - binaryData);
    }

    if (classCount == 0) {
        printf("[ClassDumpC] No ObjC classes found for class dump\n");
        return false;
    }

    printf("[ClassDumpC] Parsed %d classes for class dump\n", classCount);
    return true;
}

bool class_dump_analyze_categories(const char* binaryData, size_t binarySize, class_dump_result_t* result) {
    if (!binaryData || !result) {
        return false;
    }
    
    const char* categoryPattern = "_OBJC_CATEGORY_$_";
    const char* pos = binaryData;
    size_t remaining = binarySize;
    int categoryCount = 0;

    while (remaining > strlen(categoryPattern)) {
        pos = memchr(pos, categoryPattern[0], remaining);
        if (!pos) break;

        if (strncmp(pos, categoryPattern, strlen(categoryPattern)) == 0) {
            const char *name_start = pos + strlen(categoryPattern);
            size_t name_remaining = binarySize - (name_start - binaryData);
            char *raw_name = class_dump_safe_strndup(name_start, name_remaining);
            if (raw_name) {
                char *class_name = NULL;
                char *category_name = NULL;
                class_dump_split_category(raw_name, &class_name, &category_name);
                if (category_name) {
                    const char *resolved_class = (class_name && strlen(class_name) > 0) ? class_name : "NSObject";
                    category_dump_info_t *category_info = class_dump_add_category_with_class(result, resolved_class, category_name);
                    if (category_info) {
                        class_dump_log_category_found(category_name, category_info->className);
                        categoryCount++;
                    }
                }
                free(class_name);
                free(category_name);
                free(raw_name);
            }
        }

        pos++;
        remaining = binarySize - (pos - binaryData);
    }

    if (categoryCount == 0) {
        printf("[ClassDumpC] No ObjC categories found for class dump\n");
        return false;
    }

    printf("[ClassDumpC] Parsed %d categories for class dump\n", categoryCount);
    return true;
}

bool class_dump_analyze_protocols(const char* binaryData, size_t binarySize, class_dump_result_t* result) {
    if (!binaryData || !result) {
        return false;
    }
    
    const char* protocolPattern = "_OBJC_PROTOCOL_$_";
    const char* pos = binaryData;
    size_t remaining = binarySize;
    int protocolCount = 0;

    while (remaining > strlen(protocolPattern)) {
        pos = memchr(pos, protocolPattern[0], remaining);
        if (!pos) break;

        if (strncmp(pos, protocolPattern, strlen(protocolPattern)) == 0) {
            const char *name_start = pos + strlen(protocolPattern);
            size_t name_remaining = binarySize - (name_start - binaryData);
            char *protocolName = class_dump_safe_strndup(name_start, name_remaining);
            if (protocolName) {
                add_protocol_to_result(result, protocolName);
                class_dump_log_protocol_found(protocolName);
                free(protocolName);
                protocolCount++;
            }
        }

        pos++;
        remaining = binarySize - (pos - binaryData);
    }

    if (protocolCount == 0) {
        printf("[ClassDumpC] No ObjC protocols found for class dump\n");
        return false;
    }

    printf("[ClassDumpC] Parsed %d protocols for class dump\n", protocolCount);
    return true;
}

// MARK: - String Utilities

char* class_dump_extract_class_name(const char* symbolName) {
    if (!symbolName) return NULL;
    
    if (strstr(symbolName, "_OBJC_CLASS_$_")) {
        return strdup(symbolName + 14);
    }
    
    return strdup(symbolName);
}

char* class_dump_extract_category_name(const char* symbolName) {
    if (!symbolName) return NULL;
    
    if (strstr(symbolName, "_OBJC_CATEGORY_$_")) {
        return strdup(symbolName + 16);
    }
    
    return strdup(symbolName);
}

char* class_dump_extract_protocol_name(const char* symbolName) {
    if (!symbolName) return NULL;
    
    if (strstr(symbolName, "_OBJC_PROTOCOL_$_")) {
        return strdup(symbolName + 17);
    }
    
    return strdup(symbolName);
}

char* class_dump_extract_method_name(const char* methodData) {
    if (!methodData) return NULL;
    
    // method name extraction not done yet
    return strdup("method");
}

char* class_dump_extract_property_name(const char* propertyData) {
    if (!propertyData) return NULL;
    
    // not done yet
    return strdup("property");
}

char* class_dump_extract_ivar_name(const char* ivarData) {
    if (!ivarData) return NULL;
    
    // ivar might be the hardest one ig not finished yet
    return strdup("ivar");
}

// MARK: - Type Encoding and Decoding

char* class_dump_decode_type_encoding(const char* encoding) {
    if (!encoding) return NULL;
    
    char* result = malloc(strlen(encoding) * 2);
    if (!result) return NULL;
    
    strcpy(result, encoding);
    
    if (strstr(result, "v")) {
        result = strdup("void");
    } else if (strstr(result, "@")) {
        result = strdup("id");
    } else if (strstr(result, ":")) {
        result = strdup("SEL");
    } else if (strstr(result, "c")) {
        result = strdup("char");
    } else if (strstr(result, "i")) {
        result = strdup("int");
    } else if (strstr(result, "s")) {
        result = strdup("short");
    } else if (strstr(result, "l")) {
        result = strdup("long");
    } else if (strstr(result, "q")) {
        result = strdup("long long");
    } else if (strstr(result, "C")) {
        result = strdup("unsigned char");
    } else if (strstr(result, "I")) {
        result = strdup("unsigned int");
    } else if (strstr(result, "S")) {
        result = strdup("unsigned short");
    } else if (strstr(result, "L")) {
        result = strdup("unsigned long");
    } else if (strstr(result, "Q")) {
        result = strdup("unsigned long long");
    } else if (strstr(result, "f")) {
        result = strdup("float");
    } else if (strstr(result, "d")) {
        result = strdup("double");
    } else if (strstr(result, "B")) {
        result = strdup("BOOL");
    } else if (strstr(result, "*")) {
        result = strdup("char*");
    } else if (strstr(result, "#")) {
        result = strdup("Class");
    }
    
    return result;
}

char* class_dump_extract_property_type(const char* attributes) {
    if (!attributes) return NULL;
    
    if (strstr(attributes, "T@\"")) {
        char* start = strstr(attributes, "T@\"");
        if (start) {
            start += 3;
            char* end = strstr(start, "\"");
            if (end) {
                size_t len = end - start;
                char* type = malloc(len + 1);
                strncpy(type, start, len);
                type[len] = '\0';
                return type;
            }
        }
    }
    
    return strdup("id");
}

// MARK: - Utility Functions

bool class_dump_is_swift_class(const char* className) {
    if (!className) return false;
    
    return strstr(className, "_TtC") != NULL ||
           strstr(className, "_Tt") != NULL ||
           strstr(className, "Swift") != NULL;
}

bool class_dump_is_meta_class(const char* className) {
    if (!className) return false;
    
    return strstr(className, "_OBJC_METACLASS_$_") != NULL;
}

bool class_dump_is_class_method(const char* methodName) {
    if (!methodName) return false;
    
    return strstr(methodName, "_OBJC_$_CLASS_METHODS_") != NULL;
}

bool class_dump_is_instance_method(const char* methodName) {
    if (!methodName) return false;
    
    return strstr(methodName, "_OBJC_$_INSTANCE_METHODS_") != NULL;
}

bool class_dump_is_optional_method(const char* methodName) {
    if (!methodName) return false;
    
    return strstr(methodName, "optional") != NULL;
}

// MARK: - Memory Management

void class_dump_free_class_info(class_dump_info_t* classInfo) {
    if (!classInfo) return;
    
    free(classInfo->className);
    free(classInfo->superclassName);
    
    if (classInfo->protocols) {
        for (uint32_t i = 0; i < classInfo->protocolCount; i++) {
            free(classInfo->protocols[i]);
        }
        free(classInfo->protocols);
    }
    
    if (classInfo->instanceMethods) {
        for (uint32_t i = 0; i < classInfo->instanceMethodCount; i++) {
            free(classInfo->instanceMethods[i]);
        }
        free(classInfo->instanceMethods);
    }
    
    if (classInfo->classMethods) {
        for (uint32_t i = 0; i < classInfo->classMethodCount; i++) {
            free(classInfo->classMethods[i]);
        }
        free(classInfo->classMethods);
    }
    
    if (classInfo->properties) {
        for (uint32_t i = 0; i < classInfo->propertyCount; i++) {
            free(classInfo->properties[i]);
        }
        free(classInfo->properties);
    }
    
    if (classInfo->ivars) {
        for (uint32_t i = 0; i < classInfo->ivarCount; i++) {
            free(classInfo->ivars[i]);
        }
        free(classInfo->ivars);
    }
}

void class_dump_free_category_info(category_dump_info_t* categoryInfo) {
    if (!categoryInfo) return;
    
    free(categoryInfo->categoryName);
    free(categoryInfo->className);
    
    if (categoryInfo->protocols) {
        for (uint32_t i = 0; i < categoryInfo->protocolCount; i++) {
            free(categoryInfo->protocols[i]);
        }
        free(categoryInfo->protocols);
    }
    
    if (categoryInfo->instanceMethods) {
        for (uint32_t i = 0; i < categoryInfo->instanceMethodCount; i++) {
            free(categoryInfo->instanceMethods[i]);
        }
        free(categoryInfo->instanceMethods);
    }
    
    if (categoryInfo->classMethods) {
        for (uint32_t i = 0; i < categoryInfo->classMethodCount; i++) {
            free(categoryInfo->classMethods[i]);
        }
        free(categoryInfo->classMethods);
    }
    
    if (categoryInfo->properties) {
        for (uint32_t i = 0; i < categoryInfo->propertyCount; i++) {
            free(categoryInfo->properties[i]);
        }
        free(categoryInfo->properties);
    }
}

void class_dump_free_protocol_info(protocol_dump_info_t* protocolInfo) {
    if (!protocolInfo) return;
    
    free(protocolInfo->protocolName);
    
    if (protocolInfo->protocols) {
        for (uint32_t i = 0; i < protocolInfo->protocolCount; i++) {
            free(protocolInfo->protocols[i]);
        }
        free(protocolInfo->protocols);
    }
    
    if (protocolInfo->methods) {
        for (uint32_t i = 0; i < protocolInfo->methodCount; i++) {
            free(protocolInfo->methods[i]);
        }
        free(protocolInfo->methods);
    }
}

void class_dump_free_result(class_dump_result_t* result) {
    if (!result) return;
    
    if (result->classes) {
        for (uint32_t i = 0; i < result->classCount; i++) {
            class_dump_free_class_info(&result->classes[i]);
        }
        free(result->classes);
    }
    
    if (result->categories) {
        for (uint32_t i = 0; i < result->categoryCount; i++) {
            class_dump_free_category_info(&result->categories[i]);
        }
        free(result->categories);
    }
    
    if (result->protocols) {
        for (uint32_t i = 0; i < result->protocolCount; i++) {
            class_dump_free_protocol_info(&result->protocols[i]);
        }
        free(result->protocols);
    }
    
    if (result->generatedHeader) {
        free(result->generatedHeader);
    }
    
    free(result);
}

// MARK: - Debug and Logging

void class_dump_log_analysis_start(const char* binaryPath) {
    printf("[ClassDumpC] Starting class dump analysis of: %s\n", binaryPath);
}

void class_dump_log_class_found(const char* className, uint64_t address) {
    printf("[ClassDumpC] Found class for dump: %s at 0x%llx\n", className, address);
}

void class_dump_log_category_found(const char* categoryName, const char* className) {
    printf("[ClassDumpC] Found category for dump: %s on %s\n", categoryName, className);
}

void class_dump_log_protocol_found(const char* protocolName) {
    printf("[ClassDumpC] Found protocol for dump: %s\n", protocolName);
}

void class_dump_log_method_found(const char* methodName, const char* className) {
    printf("[ClassDumpC] Found method for dump: %s in %s\n", methodName, className);
}

void class_dump_log_property_found(const char* propertyName, const char* className) {
    printf("[ClassDumpC] Found property for dump: %s in %s\n", propertyName, className);
}

void class_dump_log_header_generated(const char* headerPath, size_t headerSize) {
    printf("[ClassDumpC] Generated header: %s (%zu bytes)\n", headerPath, headerSize);
}

void class_dump_log_analysis_complete(const class_dump_result_t* result) {
    if (!result) return;
    
    printf("[ClassDumpC] Class dump complete: %u classes, %u categories, %u protocols\n", 
           result->classCount, result->categoryCount, result->protocolCount);
}
