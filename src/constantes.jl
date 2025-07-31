# ===== CONSTANTS =====
# Library version and buffer size constants for optimal performance

"""Current version of the MicroUI library"""
const VERSION = "1.1.0"

"""Size of the command buffer in bytes - stores all rendering commands for a frame"""
const COMMANDLIST_SIZE = 256 * 1024

"""Maximum number of root containers (windows) that can be active simultaneously"""
const ROOTLIST_SIZE = 32

"""Maximum depth of nested containers (windows, panels, etc.)"""
const CONTAINERSTACK_SIZE = 32

"""Maximum depth of clipping rectangle stack for nested clipping regions"""
const CLIPSTACK_SIZE = 32

"""Maximum depth of ID stack for hierarchical widget identification"""
const IDSTACK_SIZE = 32

"""Maximum depth of layout stack for nested layout contexts"""
const LAYOUTSTACK_SIZE = 16

"""Size of the container pool for efficient container reuse"""
const CONTAINERPOOL_SIZE = 48

"""Size of the treenode pool for efficient treenode state management"""
const TREENODEPOOL_SIZE = 48

"""Maximum number of columns in a layout row"""
const MAX_WIDTHS = 16

"""Maximum length for number format strings"""
const MAX_FMT = 127

"""Default format string for real number display"""
const REAL_FMT = "%.3g"

"""Default format string for slider values"""
const SLIDER_FMT = "%.2f"

"""Hash constant for ID generation"""
const HASH_INITIAL = 0x811c9dc5
