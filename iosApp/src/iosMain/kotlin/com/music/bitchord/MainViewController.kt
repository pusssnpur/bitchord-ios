package com.music.bitchord

import androidx.compose.ui.window.ComposeUIViewController
import com.music.bitchord.ui.BitChordApp
import kotlinx.cinterop.*
import platform.UIKit.UIViewController

class MainViewController : UIViewController() {

    private val composeViewController: ComposeUIViewController by lazy {
        ComposeUIViewController {
            BitChordApp()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChildViewController(composeViewController)
        view.addSubview(composeViewController.view)
        composeViewController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            composeViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            composeViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            composeViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composeViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        composeViewController.didMoveToParentViewController(this)
    }
}