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

const myLoader = ({ src, width, quality }) => {
  return `${src}`
}

function Nft() {
  const { loading, error, nft } = useNft(
    "0xD0141E899a65C95a556fE2B27e5982A6DE7fDD7A",
    "1"
  )

  // nft.loading is true during load.
  if (loading) return <>Loading…</>

  // nft.error is an Error instance in case of error.
  if (error || !nft) return <>Error.</>

  // You can now display the NFT metadata.
  return (
    <section>
      <h1>{nft.name}</h1>
      <Image loader={myLoader} src={nft.image} alt="" width={500} height={500}/>
      <p>{nft.description}</p>
      <p>Owner: {nft.owner}</p>
      <p>Metadata URL: {nft.metadataUrl}</p>
    </section>
  )
}