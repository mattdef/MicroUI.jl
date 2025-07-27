# ![microui](https://user-images.githubusercontent.com/3920290/75171571-be83c500-5723-11ea-8a50-504cc2ae1109.png)
A *tiny*, portable, immediate-mode UI library written in Julia

Port from [rxi/microui](https://github.com/rxi/microui)

## Features
* Tiny
* Works within a fixed-sized memory region: no additional memory is allocated
* Built-in controls: window, scrollable panel, button, slider, textbox, label,
  checkbox, wordwrapped text
* Works with any rendering system that can draw rectangles and text
* Designed to allow the user to easily add custom controls
* Simple layout system

## Example
![example](https://user-images.githubusercontent.com/3920290/75187058-2b598800-5741-11ea-9358-38caf59f8791.png)
```c

ASAP...

```

## Screenshot
![screenshot](https://user-images.githubusercontent.com/3920290/75188642-63ae9580-5744-11ea-9eee-d753ff5c0aa7.png)

## Notes
The library expects the user to provide input and handle the resultant drawing
commands, it does not do any drawing itself.

## Contributing
The library is designed to be lightweight, providing a foundation to which you
can easily add custom controls and UI elements; pull requests adding additional
features will likely not be merged. Bug reports are welcome.

## License
This library is free software; you can redistribute it and/or modify it under
the terms of the MIT license. See [LICENSE](LICENSE) for details.

## Todo
**1. Focus and Input Management**
Manage the tab to navigate between controls (accessibility).

**2. Layout Management**
The layout is very basic (row/col).
→ Add helpers for more complex layouts (grid, auto-sizing, etc.).

**3. Extensibility**
Colors and styles are hard-coded in default_style.
→ Allow for easier loading of themes or customization.

**4. Input Management**
The input_* functions are very simple.
→ Add support for scrolling, special keys, copy/paste, etc.

**5. Documentation**
Add more docstrings on public functions and usage examples.

**6. Tests**
Cover more cases: keyboard navigation, lost focus, etc.

**7. Renderer API**
The renderer API is minimalist.
→ Allows easy connection to other backends (GLFW, SDL, etc.).
