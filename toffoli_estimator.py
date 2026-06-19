import qsharp
from plot import plot_multiplier_scaling

# 1. Initialize the Q# environment and load your quantum arithmetic namespace

import qsharp

def estimate_multiplier(method_name, n):
    r_size = 2 * n if method_name == "Naive" else 2 * n + 1
    operation_call = "NaiveMultiplication(x, y, r);" if method_name == "Naive" else "AddSubtractMultiplication(x, y, r);"
    
    # 2. Dynamically generate a clean Q# entry point
    # 2. Dynamically generate a clean Q# entry point
    entry_point = f"""
    open Microsoft.Quantum.Measurement;
    open QuantumArithmetic; 
    
    operation Profile_Multiplication() : Result[] {{
        use x = Qubit[{n}];
        use y = Qubit[{n}];
        use r = Qubit[{r_size}];
        
        // --- THE FIX: OPAQUE INPUTS ---
        // Put x and y into a full superposition to prevent 
        // the compiler from classically pre-computing 0 * 0
        for q in x {{ H(q); }}
        for q in y {{ H(q); }}
        
        {operation_call}
        
        // Measure to prevent Dead Code Elimination
        let results = MResetEachZ(r);
        
        // Clean up memory
        ResetAll(x);
        ResetAll(y);
        
        return results;
    }}
    """
    
    qsharp.eval(entry_point)
    result = qsharp.estimate("Profile_Multiplication()")
    toffoli_count = result.get('logicalCounts', {}).get('cczCount', 0)
    
    return toffoli_count