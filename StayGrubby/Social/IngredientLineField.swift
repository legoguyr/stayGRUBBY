import SwiftUI
import UIKit

/// A native single-line control whose Return delegate keeps the SAME first responder.
/// SwiftUI's default submit/resign cycle can drop fast input between ingredient rows.
struct IngredientLineField: UIViewRepresentable {
    @Environment(\.dynamicTypeSize) private var size
    @Environment(\.colorScheme) private var scheme
    @Binding var text: String
    var ingredientID: UUID
    var focused: Bool
    var focusChanged: (Bool) -> Void
    var submit: () -> Void
    var paste: ([String]) -> Void
    var done: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextField {
        let field=UITextField()
        field.delegate=context.coordinator
        context.coordinator.field=field
        field.attributedPlaceholder=NSAttributedString(string:"e.g. 2 tbsp olive oil",attributes:[.foregroundColor:UIColor.secondaryLabel])
        field.font=font
        field.adjustsFontForContentSizeCategory=true
        field.textColor = .label
        field.autocapitalizationType = .none
        field.returnKeyType = .next
        field.enablesReturnKeyAutomatically=false
        field.accessibilityIdentifier="recipe-ingredient-line"
        field.accessibilityLabel="Ingredient line"
        field.accessibilityHint="Type an ingredient and press Return for the next line"
        field.setContentHuggingPriority(.defaultLow,for:.horizontal)
        field.setContentCompressionResistancePriority(.defaultLow,for:.horizontal)
        let target=ingredientID
        let accessory=UIHostingController(rootView: IngredientKeyboardAccessory(targetID:target,size:size,scheme:scheme,paste:{ [weak coordinator=context.coordinator] values in
            guard coordinator?.parent.ingredientID == target else { return }
            coordinator?.paste(values,target:target)
        },done:{ [weak coordinator=context.coordinator] in coordinator?.parent.done() }))
        accessory.view.backgroundColor = .clear
        accessory.view.frame=CGRect(x:0,y:0,width:1,height:max(50,font.lineHeight+20))
        accessory.view.autoresizingMask = [.flexibleWidth]
        context.coordinator.accessory=accessory
        field.inputAccessoryView=accessory.view
        field.addTarget(context.coordinator,action:#selector(Coordinator.changed(_:)),for:.editingChanged)
        return field
    }
    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent=self
        if field.font != font { field.font=font; field.invalidateIntrinsicContentSize() }
        if let accessory=context.coordinator.accessory, accessory.rootView.size != size || accessory.rootView.scheme != scheme || accessory.rootView.targetID != ingredientID {
            let target=ingredientID
            accessory.rootView=IngredientKeyboardAccessory(targetID:target,size:size,scheme:scheme,paste:{ [weak coordinator=context.coordinator] values in
                guard coordinator?.parent.ingredientID == target else { return }
                coordinator?.paste(values,target:target)
            },done:{ [weak coordinator=context.coordinator] in coordinator?.parent.done() })
            accessory.view.frame.size.height=max(50,font.lineHeight+20)
        }
        field.keyboardAppearance = scheme == .dark ? .dark : .light
        if field.text != text { field.text=text }
        field.tintColor=UIColor(SGTheme.ColorToken.accent)
        if focused && !field.isFirstResponder {
            DispatchQueue.main.async { [weak field, weak coordinator=context.coordinator] in
                guard let field, field.window != nil, coordinator?.parent.focused == true else { return }
                field.becomeFirstResponder()
            }
        } else if !focused && field.isFirstResponder { field.resignFirstResponder() }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        guard let width=proposal.width else { return nil }
        return CGSize(width:width,height:max(44,(uiView.font?.lineHeight ?? 20)+24))
    }
    private var font: UIFont {
        let category: UIContentSizeCategory
        switch size {
        case .xSmall: category = .extraSmall
        case .small: category = .small
        case .medium: category = .medium
        case .large: category = .large
        case .xLarge: category = .extraLarge
        case .xxLarge: category = .extraExtraLarge
        case .xxxLarge: category = .extraExtraExtraLarge
        case .accessibility1: category = .accessibilityMedium
        case .accessibility2: category = .accessibilityLarge
        case .accessibility3: category = .accessibilityExtraLarge
        case .accessibility4: category = .accessibilityExtraExtraLarge
        case .accessibility5: category = .accessibilityExtraExtraExtraLarge
        @unknown default: category = .large
        }
        return UIFont.preferredFont(forTextStyle:.body,compatibleWith:UITraitCollection(preferredContentSizeCategory:category))
    }
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: IngredientLineField
        weak var field: UITextField?
        fileprivate var accessory: UIHostingController<IngredientKeyboardAccessory>?
        init(_ parent: IngredientLineField) { self.parent=parent }
        func paste(_ values: [String], target: UUID) {
            guard parent.ingredientID == target, let field else { return }
            let current=field.text ?? ""
            let inserted=values.joined(separator:"\n")
            let selection=field.selectedTextRange
            let start=selection.map { field.offset(from:field.beginningOfDocument,to:$0.start) } ?? current.utf16.count
            let end=selection.map { field.offset(from:field.beginningOfDocument,to:$0.end) } ?? start
            guard let range=Range(NSRange(location:start,length:end-start),in:current) else { return }
            // Match native Paste semantics: keep unselected text, never overwrite it.
            parent.paste([current.replacingCharacters(in:range,with:inserted)])
            field.text=parent.text
        }
        @objc func changed(_ field: UITextField) { parent.text=field.text ?? "" }
        func textFieldDidBeginEditing(_ field: UITextField) { if !parent.focused { parent.focusChanged(true) } }
        func textFieldDidEndEditing(_ field: UITextField) { if parent.focused { parent.focusChanged(false) } }
        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.text=field.text ?? ""
            parent.submit()
            // Reset synchronously before the next key event; never resign/reacquire.
            field.text=parent.text
            return false
        }
        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard string.contains(where: { $0.isNewline }), let current=field.text, let r=Range(range,in:current) else { return true }
            parent.text=current.replacingCharacters(in:r,with:string)
            field.text=parent.text
            return false
        }
    }
}

private struct IngredientKeyboardAccessory: View {
    let targetID: UUID
    let size: DynamicTypeSize
    let scheme: ColorScheme
    let paste: ([String]) -> Void
    let done: () -> Void
    var body: some View {
        HStack {
            Spacer()
            Button("Done",action:done).frame(minWidth:44,minHeight:44).accessibilityIdentifier("recipe-keyboard-done")
        }.padding(.horizontal,16).frame(maxWidth:.infinity,maxHeight:.infinity)
            .tint(SGTheme.ColorToken.accent).background(.bar)
            .environment(\.dynamicTypeSize,size).environment(\.colorScheme,scheme)
    }
}
