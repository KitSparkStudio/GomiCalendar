//
//  GomiWidgetBundle.swift
//  GomiWidget
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import SwiftUI
import WidgetKit

@main
struct GomiWidgetBundle: WidgetBundle {
    var body: some Widget {
        GomiWidget()
        GomiLiveActivityWidget()
    }
}
