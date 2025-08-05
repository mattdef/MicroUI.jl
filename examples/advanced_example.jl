include("../src/MicroUI.jl")
using .MicroUI
using .MicroUI.Macros

include("text_renderer.jl")

"""
    demo_tabs_advanced()

Advanced demonstration of the tab system with complex content.
Shows integration with all MicroUI features including state management,
reactive variables, panels, and event handling.
"""
function demo_tabs_advanced()
    println("🚀 Advanced tab system demonstration...")
    
    ctx = create_context()
    renderer = SimpleTextRenderer(80, 30)
    
    for frame in 1:3
        println("Frame $frame")
        
        @frame ctx begin
            @window "Advanced Tab Demo" size=(700, 500) begin
                @text app_title = "Tab System Demo - Frame $frame"
                
                @tabbar "advanced_demo_tabs" begin
                    @tab "🏠 Dashboard" begin
                        @text welcome = "Welcome to the Dashboard!"
                        
                        @panel "Real-time Metrics" begin
                            # Store variables with @var
                            @var users_online = 1000 + (frame * 50)
                            @var cpu_usage = 0.25 + (frame * 0.05)
                            @var memory_usage = 0.40 + (frame * 0.03)
                            
                            # Read variables with @state() for display
                            @simple_label users_display = "👥 Users Online: $(@state(users_online))"
                            @simple_label cpu_display = "💻 CPU Usage: $(round(@state(cpu_usage) * 100, digits=1))%"
                            @simple_label memory_display = "🧠 Memory: $(round(@state(memory_usage) * 100, digits=1))%"
                        end
                        
                        @panel "Quick Actions" begin
                            @button refresh_data = "🔄 Refresh Data"
                            @button export_report = "📊 Export Report"
                            @button system_status = "⚡ System Status"
                        end
                    end
                    
                    @tab "👤 User Profile" begin
                        @text profile_title = "User Profile Management"
                        
                        # Store user data
                        @var user_name = "John Developer"
                        @var user_email = "john@company.com"
                        @var user_role = "Senior Developer"
                        @var last_login = "2 hours ago"
                        
                        @panel "Personal Information" begin
                            @textbox name_field = @state(user_name)
                            @textbox email_field = @state(user_email)
                            @simple_label role_display = "Role: $(@state(user_role))"
                            @simple_label login_display = "Last Login: $(@state(last_login))"
                        end
                        
                        @panel "Preferences" begin
                            @var enable_notifications = (frame % 2 == 1)
                            @var dark_theme = (frame % 3 == 0)
                            @var auto_save = true
                            
                            @checkbox notifications_toggle = @state(enable_notifications)
                            @simple_label notif_label = "Email Notifications"
                            
                            @checkbox theme_toggle = @state(dark_theme)
                            @simple_label theme_label = "Dark Theme"
                            
                            @checkbox autosave_toggle = @state(auto_save)
                            @simple_label autosave_label = "Auto-save Documents"
                        end
                        
                        @button save_profile = "💾 Save Profile"
                        @button reset_password = "🔑 Reset Password"
                    end
                    
                    @tab "⚙️ Application Settings" begin
                        @text settings_title = "Application Configuration"
                        
                        @panel "General Settings" begin
                            @var app_name = "MicroUI Demo"
                            @var version = "1.0.0"
                            @var startup_behavior = "restore_session"
                            
                            @textbox app_name_field = @state(app_name)
                            @simple_label version_display = "Version: $(@state(version))"
                            @simple_label startup_display = "Startup: $(@state(startup_behavior))"
                        end
                        
                        @panel "Performance Settings" begin
                            @var max_memory = 0.75 + (frame * 0.05)
                            @var thread_count = 4 + frame
                            @var cache_enabled = true
                            
                            @slider memory_limit = @state(max_memory) range(0.1, 1.0)
                            @reactive memory_percent = round(@state(max_memory) * 100, digits=0)
                            @simple_label memory_display = "Memory Limit: $(memory_percent)%"
                            
                            @number threads_setting = @state(thread_count) step(1)
                            @simple_label threads_display = "Worker Threads: $(@state(thread_count))"
                            
                            @checkbox cache_toggle = @state(cache_enabled)
                            @simple_label cache_label = "Enable Caching"
                        end
                        
                        @button apply_settings = "✅ Apply Settings"
                        @button restore_defaults = "🔄 Restore Defaults"
                    end
                    
                    @tab "📈 Analytics" begin
                        @text analytics_title = "Performance Analytics"
                        
                        @panel "Usage Statistics" begin
                            @var daily_users = 2500 + (frame * 100)
                            @var session_duration = 450 + (frame * 30)
                            @var page_views = 15000 + (frame * 500)
                            
                            @simple_label users_stat = "📊 Daily Users: $(@state(daily_users))"
                            @simple_label duration_stat = "⏱️ Avg Session: $(@state(session_duration))s"
                            @simple_label views_stat = "👀 Page Views: $(@state(page_views))"
                        end
                        
                        @panel "Performance Metrics" begin
                            @var response_time = 120 - (frame * 10)
                            @var error_rate = 0.02 + (frame * 0.005)
                            @var uptime = 99.95 - (frame * 0.01)
                            
                            @simple_label response_display = "⚡ Response Time: $(@state(response_time))ms"
                            @simple_label error_display = "❌ Error Rate: $(round(@state(error_rate) * 100, digits=2))%"
                            @simple_label uptime_display = "✅ Uptime: $(round(@state(uptime), digits=2))%"
                        end
                        
                        @panel "Data Visualization" begin
                            # Simulate progress bars with sliders
                            @var metric1 = min(1.0, frame * 0.3)
                            @var metric2 = min(1.0, (frame - 1) * 0.4)
                            @var metric3 = min(1.0, (frame - 2) * 0.25)
                            
                            @slider progress1 = @state(metric1) range(0.0, 1.0)
                            @simple_label progress1_label = "Engagement: $(round(@state(metric1) * 100, digits=0))%"
                            
                            @slider progress2 = @state(metric2) range(0.0, 1.0)
                            @simple_label progress2_label = "Retention: $(round(@state(metric2) * 100, digits=0))%"
                            
                            @slider progress3 = @state(metric3) range(0.0, 1.0)
                            @simple_label progress3_label = "Conversion: $(round(@state(metric3) * 100, digits=0))%"
                        end
                        
                        @button export_analytics = "📤 Export Data"
                        @button generate_report = "📋 Generate Report"
                    end
                end
                
                # Global content below tabs
                @panel "Global Actions" begin
                    @var system_status = "All systems operational - Frame $frame"
                    @simple_label status_display = "Status: $(@state(system_status))"
                    
                    @button global_save = "💾 Save All"
                    @button global_sync = "🔄 Sync Data"
                    @button help_support = "❓ Help & Support"
                end
            end
        end
        
        render_context!(renderer, ctx)
        if frame == 2  # Display middle frame
            println("\n📺 Frame $frame Display:")
            display!(renderer)
        end
        
        sleep(1.5)
    end
    
    println("✅ Corrected demonstration completed successfully!")
    clear_widget_states!()
end

# ===== MAIN DEMO RUNNER =====

"""
Main function to run all demos
"""
function run_all_demos()
    println("🚀 MicroUI.jl - Advanced Demo Suite")
    println("=" ^ 50)
    
    while true
        println("Choose a demo:")
        println("1. Tabs Demo")
        println("2. Exit")
        
        print("Enter choice (1-2): ")
        choice = strip(readline())
        
        try
            if choice == "1"
                demo_tabs_advanced()
            elseif choice == "2"
                println("👋 Thanks for trying MicroUI!")
                break
            else
                println("❌ Invalid choice. Please enter 1-2.")
            end
        catch e
            println("❌ Error running demo: $e")
            println("Please try again.")
        end
    end
end

# Uncomment to run demos when file is executed
run_all_demos()