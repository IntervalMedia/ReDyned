#ifndef TypeAnalyzerC_h
#define TypeAnalyzerC_h

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

// MARK: - C Helper Functions for Direct Binary Parsing

bool c_is_class_symbol(const char* name);
bool c_is_struct_symbol(const char* name);
bool c_is_enum_symbol(const char* name);
bool c_is_protocol_symbol(const char* name);
bool c_is_function_symbol(const char* name);
bool c_is_property_symbol(const char* name, const char* typeName);
bool c_is_method_symbol(const char* name, const char* typeName);
bool c_is_enum_case_symbol(const char* name, const char* enumName);

char* c_extract_class_name(const char* symbolName);
char* c_extract_struct_name(const char* symbolName);
char* c_extract_enum_name(const char* symbolName);
char* c_extract_protocol_name(const char* symbolName);
char* c_extract_function_name(const char* symbolName);
char* c_extract_property_name(const char* name, const char* typeName);
char* c_extract_method_name(const char* name, const char* typeName);
char* c_extract_enum_case_name(const char* name, const char* enumName);
char* c_infer_property_type(const char* name, uint64_t size);
char* c_infer_return_type(const char* name, uint64_t size);
int c_infer_access_level(const char* name);

bool c_contains_class_definition(const char* string);
bool c_contains_struct_definition(const char* string);
bool c_contains_enum_definition(const char* string);
char* c_extract_type_name_from_string(const char* string, const char* keyword);

uint64_t c_estimate_class_size(const char* className);
uint64_t c_estimate_struct_size(const char* structName);
uint64_t c_estimate_enum_size(const char* enumName);

void c_free_string(char* str);

// MARK: - Type Reconstruction C API

typedef enum {
	C_TYPE_CATEGORY_STRUCT = 0,
	C_TYPE_CATEGORY_CLASS,
	C_TYPE_CATEGORY_ENUM,
	C_TYPE_CATEGORY_PROTOCOL,
	C_TYPE_CATEGORY_UNKNOWN
} c_type_category_t;

typedef struct {
	char *name;
	uint64_t address;
	uint64_t size;
	c_type_category_t category;
	double confidence;
} c_reconstructed_type_t;

typedef struct {
	c_reconstructed_type_t *types;
	uint32_t type_count;
} c_type_reconstruction_result_t;

c_type_reconstruction_result_t *c_reconstruct_types_from_binary(const char *binary_path);
void c_free_reconstruction_result(c_type_reconstruction_result_t *result);

#endif
