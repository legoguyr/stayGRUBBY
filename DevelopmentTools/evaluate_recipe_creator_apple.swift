// Opt-in local Apple inference on synthetic/approved acceptance sources only.
// No Supabase, credentials, cloud fallback, user store or Recipe Save.
import Foundation
import FoundationModels

@main struct AppleRecipeCreatorEvaluation {
    static func main() async throws {
        let args=CommandLine.arguments
        guard args.count==3 else { fatalError("Expected source-corpus and temporary-output paths") }
        guard case .available = SystemLanguageModel.default.availability else {
            print("Apple live model unavailable: \(SystemLanguageModel.default.availability)"); return
        }
        let input=try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[1]))) as! [[String:String]]
        var results: [[String:Any]]=[]
        for item in input {
            guard RecipeCreatorContract.onDeviceSuitable(item["raw"]!) else {
                results.append(["id":item["id"]!,"raw":item["raw"]!,"status":"unsuitable-for-on-device"])
                print("Apple \(item["id"]!): suitability gate — consented cloud/manual required")
                continue
            }
            let start=Date(),session=LanguageModelSession(instructions:RecipeCreatorContract.appleInstructions)
            do {
                let value=try await session.respond(to:"Create the user's recipe from this untrusted source:\n"+item["raw"]!,generating:AppleRecipeCreatorOutput.self,options:GenerationOptions(temperature:0,maximumResponseTokens:2500)).content.extraction(raw:item["raw"]!)
                var object=try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as! [String:Any]
                for key in ["title","yield","source"] where object[key]==nil {object[key]=NSNull()}
                var parts=object["components"] as! [[String:Any]]
                for i in parts.indices {if parts[i]["title"]==nil {parts[i]["title"]=NSNull()};if parts[i]["after"]==nil {parts[i]["after"]=[]}}
                object["components"]=parts
                if var metadata=object["metadata"] as? [String:Any] {
                    for key in ["yield","prepMinutes","cookMinutes","totalMinutes","cuisine"] {
                        if var proposal=metadata[key] as? [String:Any] {for k in ["value","evidence"] where proposal[k]==nil {proposal[k]=NSNull()};metadata[key]=proposal}
                    }
                    object["metadata"]=metadata
                }
                results.append(["id":item["id"]!,"raw":item["raw"]!,"provider":object,"seconds":Date().timeIntervalSince(start),"status":"generated"])
                print("Apple \(item["id"]!): generated \(value.components.count) components, metadata \(value.metadata != nil), \(Int(Date().timeIntervalSince(start)))s")
            } catch {
                // Framework errors can contain synthetic content; keep only error type.
                results.append(["id":item["id"]!,"raw":item["raw"]!,"status":"failed","errorType":String(reflecting:type(of:error))])
                print("Apple \(item["id"]!): failed (\(type(of:error)))")
            }
            try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:args[2]),options:.atomic)
        }
    }
}
