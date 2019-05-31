#pragma once

#include "syntax_tree.h"

#include "llvm/IR/Verifier.h"
#include "llvm/ExecutionEngine/GenericValue.h"
#include "llvm/ExecutionEngine/Interpreter.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/ValueSymbolTable.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Support/ManagedStatic.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/FileSystem.h"

class codegen_llvm
{
    const syntax_module &module;
    llvm::LLVMContext context;
    std::shared_ptr<llvm::Module> llvm_module;

    llvm::Type *type_primary(const primary_type &t);
    llvm::Type *type_sum(const sum_type &t);
    llvm::Type *type_product(const product_type &t);
    llvm::Type *llvm_type(const syntax_type &s);

    llvm::Value *get_value(const std::shared_ptr<syntax_expr> &expr);

    llvm::IRBuilder<> *builder;

    void function(const std::string &fun_name, const std::vector<syntax_stmt> &stmts);

public:
    codegen_llvm(const syntax_module &mod) : module(mod) {}

    void codegen();
};