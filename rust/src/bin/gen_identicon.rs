use minecraft_status::{
    identicon::{self, IdenticonInput},
    mcping_common::ProtocolType,
};

fn main() {
    let input = IdenticonInput {
        protocol_type: ProtocolType::Bedrock,
        address: "try.ok.game.org",
    };
    println!("{}", identicon::make_base64_identicon(input).unwrap());
}
