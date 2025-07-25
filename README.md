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
**1. Séparation logique/rendu**
La logique d’UI et le rendu sontr trop reliés (ex : draw_rect! dans les contrôles).
→ Pour faciliter le test et le portage, séparer la génération des commandes de dessin et leur exécution.

**2. Gestion du focus et de l’input**
Ajouter des helpers pour savoir si un contrôle a le focus ou est actif.
Gérer le tab pour naviguer entre contrôles (accessibilité).

**3. Gestion du layout**
Le layout est très basique (row/col).
→ Ajouter des helpers pour des layouts plus complexes (grille, auto-sizing, etc.).

**4. Extensibilité**
Les couleurs et styles sont codés en dur dans default_style.
→ Permettre de charger des thèmes ou de personnaliser plus facilement.

**5. Gestion des entrées**
Les fonctions mu_input_* sont très simples.
→ Ajouter la gestion du scroll, des touches spéciales, du copier/coller, etc.

**6. Performance**
Les allocations (ex : création de rectangles, chaînes) pourraient être réduites dans une version plus poussée.

**7. Documentation**
Ajouter plus de docstrings sur les fonctions publiques et des exemples d’utilisation.

**8. Tests**
Couvrir plus de cas : navigation clavier, focus perdu, edge-cases de clipping, etc.

**9. API Renderer**
L’API du renderer est minimaliste.
→ Permettre de brancher d’autres backends (GLFW, SDL, etc.) facilement.

**10. Ergonomie Julia**
Utiliser des symboles ou enums pour les couleurs, les icônes, etc., plutôt que des entiers magiques.