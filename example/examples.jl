# Exemple d'utilisation de MicroUI.jl avec un backend de rendu simple
include("../src/MicroUI.jl")
using .MicroUI

# Programme principal
function main()

    # Initialisation
    ctx = Context()
    init!(ctx)

    # Variables d'état
    window_open = Ref(true)
    text_input = Ref("Tapez ici...")
    slider_val = Ref(75.0f0)
    checkbox_state = Ref(true)

    # Boucle principale
    while window_open[]
        begin_frame(ctx)
        
        if begin_window_ex(ctx, "Demo App", Rect(50, 50, 400, 300), UInt16(0)) != 0
            
            # Layout en 2 colonnes
            layout_row!(ctx, 2, [150, -1], 0)
            
            layout_begin_column!(ctx)
                text(ctx, "Colonne de gauche avec du texte qui se répartit automatiquement sur plusieurs lignes.")
                
                if button(ctx, "Action") & Int(RES_SUBMIT) != 0
                    println("Action déclenchée!")
                end
            layout_end_column!(ctx)
            
            layout_begin_column!(ctx)
                # Contrôles interactifs
                checkbox!(ctx, "Option active", checkbox_state)
                textbox!(ctx, text_input, 100)
                slider!(ctx, slider_val, 0.0f0, 100.0f0)
                
                # Tree node avec état persistant
                if begin_treenode(ctx, "Paramètres") & Int(RES_ACTIVE) != 0
                    label(ctx, "Sous-option 1")
                    label(ctx, "Sous-option 2")
                    end_treenode(ctx)
                end
            layout_end_column!(ctx)
            
            # Bouton de fermeture
            if button(ctx, "Fermer") & Int(RES_SUBMIT) != 0
                window_open[] = false
            end
            
            end_window(ctx)

        end
        
        end_frame(ctx)
        
        # Rendu (à adapter selon votre backend graphique)
        render_commands(ctx)
    end

end

# Si exécuté directement
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end