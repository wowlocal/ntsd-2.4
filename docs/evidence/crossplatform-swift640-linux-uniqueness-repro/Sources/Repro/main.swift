func check<H>(_ name: String,_ make: () -> H,_ append: (inout H,Int) -> Void,_ count: (H) -> Int) {
    var a = make(); for i in 0..<5 { append(&a,i) }
    var b = a; append(&b,99)
    b = make()                       // newer holder first: the walk must stop at a's shared head
    print(name,"older kept after newer dropped:",count(a),"(expected 5)")
    var c = a; append(&c,7); a = make()
    print(name,"newer kept after older dropped:",count(c),"(expected 6)")
    c = make()
    var d = make(); for i in 0..<3 { append(&d,i) }
    var e = d; append(&e,98); append(&e,99)
    e = make()                       // unique nodes, then a shared one: the walk must stop there
    print(name,"older kept after unique-then-shared drop:",count(d),"(expected 3)")
    d = make()
    var long = make(); for i in 0..<1_000_000 { append(&long,i) }
    print(name,"long:",count(long)); long = make()
    print(name,"released")
}
switch CommandLine.arguments.dropFirst().first {
case "linked": check("linked",{ LinkHistory<Int>() },{ $0.append($1) },{ $0.count })
case "fixed": check("fixed",{ FixedHistory<Int>() },{ $0.append($1) },{ $0.count })
default: check("original",{ History<Int>() },{ $0.append($1) },{ $0.count })
}
