use identicon_rs::Identicon;
use image::EncodableLayout;

use crate::mcping_common::ProtocolType;

pub struct IdenticonInput<'a> {
    pub protocol_type: ProtocolType,
    pub address: &'a str,
}

impl<'a> IdenticonInput<'a> {
    fn to_string(&self) -> String {
        format!("{:?}{}", self.protocol_type, self.address)
    }
}

pub fn make_base64_identicon(input: IdenticonInput) -> Option<String> {
    let identicon = Identicon::new(input.to_string())
        .size(9)
        .unwrap()
        .scale(54)
        .unwrap()
        .border(6)
        .background_color((0, 0, 0));
    let dynamic_image = identicon.generate_image();
    let mut rgba_image = dynamic_image.to_rgba8();

    // Replace the background color with transparency
    //
    // We handle the background in swiftui land so we can react to system theme
    // changes
    rgba_image
        .pixels_mut()
        .filter(|p| *p == &image::Rgba([0, 0, 0, 255]))
        .for_each(|p| *p = image::Rgba([0, 0, 0, 0]));

    let mut buffer = Vec::new();

    image::png::PngEncoder::new(&mut buffer)
        .encode(
            rgba_image.as_bytes(),
            rgba_image.width(),
            rgba_image.height(),
            image::ColorType::Rgba8,
        )
        .ok()?;

    Some(base64::encode(&buffer))
}
