using Logging
using PythonCall # <--- Nuevo paquete: PythonCall.jl
using Base.Filesystem

# 1. Configurar el nivel mínimo de logging
global_logger(ConsoleLogger(stderr, Logging.Info))

"""
    execute_python_script_pythoncall(script_path::String, function_name::String, args...)

Intenta ejecutar una función específica dentro de un script Python utilizando PythonCall.jl.
Registra un mensaje de información si la ejecución es exitosa,
o un mensaje de error si ocurre una excepción (incluyendo errores de Python).

Argumentos:
- `script_path`: La ruta completa o relativa al script Python.
- `function_name`: El nombre de la función dentro del script Python a ejecutar.
- `args...`: Argumentos posicionales a pasar a la función Python.
"""
function execute_python_script_pythoncall(script_path::String, function_name::String, args...)
    try
        normalized_script_path = replace(script_path, "\\" => "/")
        module_name = basename(normalized_script_path)[1:end-3] # Eliminar ".py"

        # ** Diferencia clave con PyCall: Gestión de módulos con PythonCall **
        # PythonCall tiene formas más robustas de importar.
        # Para cargar un módulo desde una ruta arbitraria:
        # 1. Añadir el directorio del script a sys.path en el lado Python.
        # 2. Importar el módulo por su nombre.

        pysys = pyimport("sys")
        # Insertar el directorio del script al principio de sys.path para que Python lo encuentre.
        # Esto es crucial para cargar scripts que no están en rutas estándar de Python.
        if !pyin(dirname(normalized_script_path), pysys.path) # Verificar si ya está en la ruta
            pysys.path.insert(0, dirname(normalized_script_path))
        end

        # pyimport() en PythonCall intentará encontrar el módulo.
        # Para asegurar una recarga limpia si el script cambia, podemos eliminarlo primero de sys.modules.
        pymodules = pyimport("sys").modules
        if pyin(module_name, pymodules)
            pydelitem(pymodules, module_name)
        end
        
        # Importar el módulo. PythonCall se encarga de los detalles.
        pymodule = pyimport(module_name)

        # Acceder a la función Python deseada desde el módulo cargado
        # PythonCall usa `pygetattr` para acceder a atributos de objetos Python.
        pyfunction = pygetattr(pymodule, function_name)

        # Ejecutar la función Python con los argumentos proporcionados
        # PythonCall permite pasar argumentos Julia directamente, y los convierte.
        result = pyfunction(args...)

        if result !== nothing
            @info "Función Python (PythonCall) '$function_name' en '$script_path' completada exitosamente. Resultado: $(string(result))"
        else
            @info "Función Python (PythonCall) '$function_name' en '$script_path' completada exitosamente. (No retornó un valor explícito)"
        end
        return result
    catch e
        # PythonCall lanza excepciones de tipo PythonCall.PyException para errores de Python
        if isa(e, PythonCall.PyException)
            @error "Fallo al ejecutar la función Python (PythonCall) '$function_name' en '$script_path'." exception=(e, catch_backtrace())
            # Puedes obtener detalles del error de Python accediendo a e.val (el objeto de excepción Python)
            pyerr_details = string(e.val) # Convierte el objeto de excepción Python a String
            @error "Detalles del error de Python (PythonCall): $pyerr_details"
        else
            @error "Fallo inesperado al ejecutar la función Python (PythonCall) '$function_name' en '$script_path'." exception=(e, catch_backtrace())
        end
        return nothing
    end
end


# Define tus rutas absolutas aquí
script_ok = "C:\\Users\\iernestov\\.scripts\\ENTORNO_JULIA\\QA\\src\\Python\\script_ok.py"
script_error = "C:\\Users\\iernestov\\.scripts\\ENTORNO_JULIA\\QA\\src\\Python\\script_error.py"

println("--- Preparando scripts Python para testeo ---")
# Asegúrate de que los archivos script_ok.py y script_error.py
# existen en las rutas especificadas arriba.

# --- Test de Ejecución Exitosa ---
println("\n--- Test de ejecución exitosa de script Python ---")
# Ahora llamamos a la nueva función `execute_python_script_pythoncall`
successful_python_result = execute_python_script_pythoncall(script_ok, "saludar", "Mundo")
println("Resultado Python exitoso: ", successful_python_result)

successful_add_result = execute_python_script_pythoncall(script_ok, "sumar", 10, 5)
println("Resultado suma exitosa: ", successful_add_result)

# --- Test de Ejecución con Error en Python ---
println("\n--- Test de ejecución de script Python con error ---")
error_python_result = execute_python_script_pythoncall(script_error, "causar_error", "dato_malo")
println("Resultado Python con error: ", error_python_result) # Será `nothing`

# --- Prueba con debug (no se mostrará con nivel Info) ---
println("\n--- Prueba con debug (no se mostrará) ---")
global_logger(ConsoleLogger(stderr, Logging.Debug))
@debug "Este mensaje de depuración ahora SÍ se mostrará."
global_logger(ConsoleLogger(stderr, Logging.Info))
@debug "Este debug NO se verá."
@info "Este info SÍ se verá."