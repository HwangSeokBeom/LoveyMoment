import SwiftUI
import UIKit

extension View {
    /// 현재 첫 응답자를 해제해 키보드를 내린다.
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    /// 빈 영역 탭으로 키보드를 내린다. 버튼 탭은 방해하지 않도록 동시 제스처로 붙인다.
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        )
    }
}
