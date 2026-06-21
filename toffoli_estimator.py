import qsharp

def estimate_multiplier(n):
    
    # Dynamically generate a clean Q# entry point
    entry_point = f"""
    open Microsoft.Quantum.Measurement;
    open QuantumArithmetic; 
    
    operation Profile_Multiplication() : Unit {{ 
        use x = Qubit[{n}];
        use y = Qubit[{n}];
        use r = Qubit[{2 * n + 1}];
        
        AddSubtractMultiplication(x, y, r);
    }}
    """

    qsharp.eval(entry_point)
    result = qsharp.estimate("Profile_Multiplication()")
    
    logical_counts = result.get('logicalCounts', {})
    ccz_count = logical_counts.get('cczCount', 0)
    
    return ccz_count