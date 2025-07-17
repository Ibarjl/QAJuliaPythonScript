# =============================================================================
# SCRIPT JULIA CON TRY-CATCH AUTOMÁTICO EN CADA CAMBIO DE FLUJO
# =============================================================================

using Dates
using HTTP
using JSON3

# Configuración
const CONTAINER_NAME = "monitoring_container_$(now())"
const LOKI_URL = "http://localhost:3100"
const PROMETHEUS_URL = "http://localhost:9090"

# =============================================================================
# FUNCIÓN PRINCIPAL CON TRY-CATCH AUTOMÁTICO
# =============================================================================

function pause_for_confirmation(message::String, error_context::String = "")
    """
    Pausa automática con confirmación manual
    """
    println("⏸️  $message")
    
    if !isempty(error_context)
        println("📋 Contexto del error:")
        println(error_context)
    end
    
    println("🔹 Opciones:")
    println("  [Enter] - Continuar")
    println("  [q] - Quit/Kill")
    println("  [r] - Retry desde esta fase")
    
    while true
        print("👤 Tu decisión: ")
        choice = readline()
        
        if choice == ""
            println("✅ Continuando...")
            return :continue
        elseif lowercase(choice) == "q"
            println("🛑 Ejecutando Kill...")
            return :kill
        elseif lowercase(choice) == "r"
            println("🔄 Reintentando...")
            return :retry
        else
            println("❌ Opción no válida. Usa Enter, 'q' o 'r'")
        end
    end
end

function safe_execute(phase_name::String, func::Function, args...; allow_retry::Bool = true)
    """
    Ejecuta una función con try-catch automático y pausa en caso de error
    """
    max_retries = allow_retry ? 3 : 1
    
    for attempt in 1:max_retries
        try
            println("🚀 Ejecutando fase: $phase_name (intento $attempt/$max_retries)")
            result = func(args...)
            println("✅ Fase '$phase_name' completada exitosamente")
            return result
            
        catch e
            error_msg = "❌ ERROR en fase '$phase_name': $e"
            println(error_msg)
            
            if attempt < max_retries
                # Pausa automática en error con opciones
                decision = pause_for_confirmation(
                    "ERROR en $phase_name - ¿Qué hacer?",
                    "Error: $e\nIntento: $attempt/$max_retries"
                )
                
                if decision == :kill
                    cleanup_resources()
                    error("🛑 Ejecución terminada por el usuario")
                elseif decision == :retry
                    println("🔄 Reintentando fase '$phase_name'...")
                    continue
                elseif decision == :continue
                    println("⏭️ Saltando fase '$phase_name'...")
                    return nothing
                end
            else
                # Última oportunidad
                decision = pause_for_confirmation(
                    "ERROR FINAL en $phase_name - Se agotaron los reintentos",
                    "Error: $e\nIntentos agotados: $max_retries"
                )
                
                if decision == :kill
                    cleanup_resources()
                    error("🛑 Ejecución terminada por el usuario")
                else
                    println("⏭️ Continuando a pesar del error...")
                    return nothing
                end
            end
        end
    end
end

# =============================================================================
# FUNCIONES DE CADA FASE
# =============================================================================

function setup_monitoring()
    """
    Configurar contenedor de monitoreo
    """
    # Detener contenedor existente si existe
    run(`docker stop $CONTAINER_NAME`, wait=false)
    run(`docker rm $CONTAINER_NAME`, wait=false)
    
    # Crear nuevo contenedor
    run(`docker run -d --name $CONTAINER_NAME -p 3100:3100 grafana/loki:latest -config.file=/etc/loki/local-config.yaml`)
    
    # Verificar que esté corriendo
    sleep(5)
    result = read(`docker ps`, String)
    if !contains(result, CONTAINER_NAME)
        error("Contenedor no se inició correctamente")
    end
    
    println("📊 Contenedor $CONTAINER_NAME iniciado exitosamente")
    return true
end

function continuous_monitoring()
    """
    Monitoreo continuo con verificaciones
    """
    for cycle in 1:5  # 5 ciclos de monitoreo
        println("🔍 Ciclo de monitoreo #$cycle")
        
        # Verificar estado del contenedor
        result = read(`docker ps`, String)
        if !contains(result, CONTAINER_NAME)
            error("Contenedor $CONTAINER_NAME no está corriendo")
        end
        
        # Simular tageo de Loki
        run(`docker exec $CONTAINER_NAME /bin/sh -c "echo 'level=info msg=\"Monitoring cycle $cycle\"' >> /var/log/loki.log"`)
        
        # Simular posible error (20% probabilidad)
        if rand() < 0.2
            error("Error simulado en ciclo $cycle")
        end
        
        println("✅ Ciclo $cycle completado")
        sleep(2)
    end
    
    return true
end

function execute_dumps(dump_type::String = "both")
    """
    Ejecutar dumps según el tipo especificado
    """
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    
    if dump_type in ["loki", "both"]
        println("📊 Ejecutando Loki dump...")
        
        # Simular dump de Loki
        loki_data = Dict("query" => "monitoring", "timestamp" => timestamp)
        open("loki_dump_$timestamp.json", "w") do f
            JSON3.write(f, loki_data)
        end
        
        println("✅ Loki dump completado: loki_dump_$timestamp.json")
    end
    
    if dump_type in ["prometheus", "both"]
        println("📈 Ejecutando Prometheus dump...")
        
        # Simular dump de Prometheus
        prometheus_data = Dict("metric" => "up", "timestamp" => timestamp)
        open("prometheus_dump_$timestamp.json", "w") do f
            JSON3.write(f, prometheus_data)
        end
        
        println("✅ Prometheus dump completado: prometheus_dump_$timestamp.json")
    end
    
    return true
end

function cleanup_resources()
    """
    Limpiar recursos
    """
    println("🧹 Limpiando recursos...")
    
    try
        run(`docker stop $CONTAINER_NAME`)
        run(`docker rm $CONTAINER_NAME`)
        println("✅ Contenedor $CONTAINER_NAME eliminado")
    catch e
        println("⚠️ Error al limpiar contenedor: $e")
    end
    
    # Limpiar archivos temporales
    for file in readdir(".")
        if contains(file, "dump_") && contains(file, ".json")
            println("🗑️ Limpiando archivo: $file")
            rm(file, force=true)
        end
    end
    
    return true
end

# =============================================================================
# FLUJO PRINCIPAL CON TRY-CATCH AUTOMÁTICO
# =============================================================================

function main()
    """
    Flujo principal con try-catch automático en cada cambio
    """
    println("🎯 Iniciando flujo de monitoreo con try-catch automático")
    println("📅 Timestamp: $(now())")
    println("🐳 Contenedor: $CONTAINER_NAME")
    println("=" ^ 60)
    
    try
        # FASE 1: Setup con try-catch automático
        safe_execute("Setup de Monitoreo", setup_monitoring)
        
        # Pausa normal después de setup exitoso
        decision = pause_for_confirmation("✅ Setup completado - ¿Continuar con monitoreo?")
        if decision == :kill
            cleanup_resources()
            return
        end
        
        # FASE 2: Monitoreo con try-catch automático
        safe_execute("Monitoreo Continuo", continuous_monitoring)
        
        # Pausa normal después de monitoreo exitoso
        decision = pause_for_confirmation("✅ Monitoreo completado - ¿Continuar con dumps?")
        if decision == :kill
            cleanup_resources()
            return
        end
        
        # Pregunta por tipo de dump
        println("📋 Selecciona tipo de dump:")
        println("  [1] - Loki")
        println("  [2] - Prometheus") 
        println("  [3] - Ambos")
        print("👤 Tu elección (1-3): ")
        
        dump_choice = readline()
        dump_type = if dump_choice == "1"
            "loki"
        elseif dump_choice == "2"
            "prometheus"
        else
            "both"
        end
        
        # FASE 3: Dumps con try-catch automático
        safe_execute("Ejecución de Dumps", execute_dumps, dump_type)
        
        println("🎉 Flujo completado exitosamente!")
        
    catch e
        println("💥 Error no manejado: $e")
        println("🧹 Ejecutando limpieza automática...")
        cleanup_resources()
        rethrow(e)
    finally
        # Pregunta final sobre limpieza
        decision = pause_for_confirmation("🧹 ¿Ejecutar limpieza de recursos?")
        if decision != :kill
            cleanup_resources()
        end
    end
end

# =============================================================================
# EJECUTAR FLUJO
# =============================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

# =============================================================================
# CÓMO USAR DESDE KESTRA
# =============================================================================

"""
Para usar este script desde Kestra:

1. OPCIÓN JULIA PURA:
   - Colocar este script en el working directory
   - Ejecutar con: julia monitoring_script.jl

2. OPCIÓN KESTRA + JULIA:
   
   id: julia_monitoring_flow
   namespace: dev.monitoring
   tasks:
     - id: run_julia_script
       type: io.kestra.plugin.scripts.shell.Commands
       commands:
         - julia monitoring_script.jl
       
       errors:
         - id: julia_error_handler
           type: io.kestra.core.tasks.flows.Pause
           description: "💥 ERROR EN JULIA - Botón Kill disponible"

VENTAJAS DE JULIA:
✅ Try-catch nativo elegante
✅ Manejo de errores muy robusto
✅ Interactividad simple con readline()
✅ Un solo archivo, un solo script
✅ Fácil de debuggar y modificar
✅ Retry automático con contadores
✅ Limpieza automática en finally
✅ Pause con opciones (continuar/kill/retry)
"""