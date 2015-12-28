Pod::Spec.new do |s|

  s.name         = "UIScreenCapture"
  s.version      = "0.0.1"
  s.summary      = "Simply capture screenshots and create screen recordings from code."

  s.description  = "Easily capture screenshots and create screen recordings from code."

  s.homepage     = "https://github.com/uxmstudio/UIScreenCapture"
  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/uxmstudio/UIScreenCapture.git", :tag => "0.0.1" }
  s.source_files  = "UIScreenCapture", "UIScreenCapture/**/*.{h,m}"
  s.requires_arc = true

end
