# ===== TYPE ALIASES =====
# Convenient type aliases for commonly used types

"""Unique identifier for widgets and containers, generated from strings"""
const Id = UInt32

"""Floating point type used for numeric values throughout the library"""
const Real = Float32

"""Font handle - can be any type depending on rendering backend"""
const Font = Any

"""Pointer/index into the command buffer for command linking"""
const CommandPtr = Int32