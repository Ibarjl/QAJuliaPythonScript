using Logging

# Puedes comentar estas líneas si solo las estás usando como recordatorio
# @debug
# @info
# @warn
# @error

# 1. Configurar el nivel mínimo de logging
# Por defecto, Julia muestra Info y niveles superiores.
# Esta línea asegura que los mensajes @debug no se muestren.
Logging.min_level(Logging.Info) # O Logging.min_enabled_level(Logging.Info)

"""
    catch_script(path_script::String)

Intenta "ejecutar" una operación representada por `path_script`.
Registra un mensaje de información si la operación es exitosa (no nula),
o un mensaje de error si ocurre una excepción.
"""
function catch_script(path_script::String)
    try
        # En tu código original, result = path_script.
        # Esto solo asignaría la cadena. Para una operación real,
        # podríamos simular algo que produce un resultado o un error.
        # Por ejemplo, intentemos "procesar" el path_script.
        # Para este ejemplo, haremos que la "operación" lance un error
        # si el path contiene la palabra "error".
        if occursin("error", path_script)
            error("Simulando un error al procesar: $path_script")
        end

        result = "Procesamiento exitoso de: $path_script" # Simula un resultado de la operación
        
        if result !== nothing
            @info "Operación '$path_script' completada exitosamente. Resultado: $(result[1:min(length(result), 50)])..." # Añadir mensaje al log
        end
        return result # Es buena práctica devolver el resultado si la operación fue exitosa
    catch e # Captura la excepción para poder registrarla
        @error "Fallo al ejecutar la operación '$path_script'." exception=(e, catch_backtrace()) # Añadir mensaje y detalles del error
        return nothing # Indicar que la operación falló
    end
end

println("--- Prueba de ejecución exitosa ---")
successful_result = catch_script("ruta/a/mi_script_exitoso.jl")
println("Resultado exitoso: ", successful_result)

println("\n--- Prueba de ejecución con error ---")
error_result = catch_script("ruta/a/mi_script_con_error.jl")
println("Resultado con error: ", error_result) # Será nothing

println("\n--- Prueba con debug (no se mostrará) ---")
Logging.min_level(Logging.Debug) # Cambiamos temporalmente para demostrar
@debug "Este mensaje de depuración ahora SÍ se mostrará."
Logging.min_level(Logging.Info) # Volvemos al nivel anterior
@debug "Este debug NO se verá."
@info "Este info SÍ se verá."

# Puedes verificar el comportamiento de los logs en tu consola.