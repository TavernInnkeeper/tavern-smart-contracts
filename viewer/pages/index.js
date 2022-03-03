import Head from 'next/head'
import Image from 'next/image'
import styles from '../styles/Home.module.css'

import { ethers } from "ethers"
import { NftProvider, useNft } from "use-nft"

const RPC_URL = "http://127.0.0.1:8545"

// We are using the "ethers" fetcher here.
const ethersConfig = {
  provider: new ethers.providers.JsonRpcProvider(RPC_URL),
}

export default function Home() {
  return (
    <NftProvider fetcher={["ethers", ethersConfig]}>
      <Nft />
    </NftProvider>
  )
}

function Nft() {
  const { loading, error, nft } = useNft(
    "0x4C4a2f8c81640e47606d3fd77B353E87Ba015584",
    "3"
  )

  // nft.loading is true during load.
  if (loading) return <>Loading…</>

  // nft.error is an Error instance in case of error.
  if (error || !nft) return <>Error.</>

  // You can now display the NFT metadata.
  return (
    <section>
      <h1>{nft.name}</h1>
      <img src={nft.image} alt="" />
      <p>{nft.description}</p>
      <p>Owner: {nft.owner}</p>
      <p>Metadata URL: {nft.metadataUrl}</p>
    </section>
  )
}