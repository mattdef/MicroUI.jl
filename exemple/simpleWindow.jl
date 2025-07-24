import MicroUI

function getExemple()
    # Création du contexte et du renderer
    ctx, renderer = MicroUI.create_context_with_buffer_renderer(800, 600)
    MicroUI.mu_init(ctx)

    # État de l'application
    checkbox_state = Ref(false)
    text_buffer = Ref("Hello, MicroUI!")

    # Boucle principale de l'application
    running = true
    while running
        MicroUI.mu_begin(ctx)

        # Créer une fenêtre
        MicroUI.mu_begin_window(ctx, "Fenêtre principale", 100, 100, 300, 200)

        # Ajouter des éléments UI
        MicroUI.mu_label(ctx, "Bienvenue dans MicroUI!")
        if MicroUI.mu_button(ctx, "Bouton")
            println("Bouton pressé!")
        end

        MicroUI.mu_checkbox(ctx, "Case à cocher", checkbox_state)
        MicroUI.mu_input_textbox(ctx, text_buffer)

        # Mise en page simple
        MicroUI.mu_layout_row(ctx)
        MicroUI.mu_label(ctx, "Un autre label")
        MicroUI.mu_label(ctx, "À côté")
        MicroUI.end_layout_row(ctx)

        MicroUI.mu_end_window(ctx)

        MicroUI.mu_end(ctx)

        # Gestion des événements (simulation pour cet exemple)
        # Dans un vrai contexte, ces événements seraient gérés par la boucle de l'application
        # Exemple de gestion d'événements fictifs
        if false # condition pour fermer la fenêtre
            running = false
        end
    end
end

# Exécuter la fonction principale
getExemple()