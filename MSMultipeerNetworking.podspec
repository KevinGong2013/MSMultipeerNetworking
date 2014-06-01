Pod::Spec.new do |s|
  s.name         = "MSMultipeerNetworking"
  s.version      = "0.0.1"
  s.summary      = "A client-server model built with Thrift on top of Apple's Multipeer Connectivity framework for iOS"
  s.description  = "A client-server model built with Thrift on top of Apple's Multipeer Connectivity framework for iOS."
  s.homepage     = "https://github.com/mstultz/MSMultipeerNetworking"
  s.license      = "MIT"
  s.author       = "Mark Stultz"
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/mstultz/MSMultipeerNetworking.git", :tag => "0.0.1" }
  s.source_files  = "MSMultipeerNetworking/*.{h,m}"
  s.requires_arc = true
end
